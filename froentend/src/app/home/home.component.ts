import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDialog } from '@angular/material/dialog';
import { MatMenuModule } from '@angular/material/menu';

// Shared Components
import { HeaderComponent } from '../shared/header/header.component';
import { FooterComponent } from '../shared/footer/footer.component';
import { AddCategoryDialogComponent } from '../shared/add-category-dialog/add-category-dialog.component';
import { AddLinkDialogComponent } from '../shared/add-link-dialog/add-link-dialog.component';

// Services
import { CategoryService } from '../service/category.service';
import { LinkService } from '../service/link.service';
import { AuthService } from '../service/auth.service';
import { SearchService } from '../service/search.service';

// Models
import { Category } from '../model/category.model';
import { Link } from '../model/link.model';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    HeaderComponent,
    FooterComponent,
    MatButtonModule,
    MatIconModule,
    MatMenuModule
  ],
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css']
})
export class HomeComponent implements OnInit {
  // ====================== SEARCH ======================
  searchQuery: string = '';
  searchLinks: Link[] = [];
  searchCategories: Category[] = [];
  searching: boolean = false;
  searchError: string = '';

  // ====================== CATEGORIES & LINKS ======================
  categories: Category[] = [];
  linksMap: Record<string, Link[]> = {};  
  visibleCount: Record<string, number> = {}; 
  loading = { categories: false, links: {} as Record<string, boolean> };
  window = window;

  constructor(
    private dialog: MatDialog,
    private categoryService: CategoryService,
    private linkService: LinkService,
    private authService: AuthService,
    private searchService: SearchService
  ) {}

  // ====================== LIFECYCLE ======================
  ngOnInit() {
    this.loadCategories();
    this.visibleCount['all'] = 6;

    this.authService.getProfile().subscribe({
      next: (profile) => console.log('User Profile:', profile),
      error: (err) => console.error('Failed to load profile:', err)
    });
  }

  // ====================== SEARCH METHODS ======================
  handleSearch() {
    if (!this.searchQuery.trim()) return;

    this.searching = true;
    this.searchError = '';
    this.searchLinks = [];
    this.searchCategories = [];

    this.searchService.search(this.searchQuery).subscribe({
      next: (res) => {
        this.searchLinks = res.links.map(link => ({
          ...link,
          _id: (link._id as any)?.$oid || link._id,
          categoryId: (link.categoryId as any)?.$oid || link.categoryId
        }));

        this.searchCategories = res.categories.map(cat => ({
          ...cat,
          _id: (cat._id as any)?.$oid || cat._id,
          userId: (cat.userId as any)?.$oid || cat.userId
        }));

        this.searching = false;
      },
      error: (err) => {
        this.searchError = err?.error?.message || 'Search failed';
        this.searching = false;
      }
    });
  }

  clearSearch() {
    this.searchQuery = '';
    this.searchLinks = [];
    this.searchCategories = [];
    this.searchError = '';
  }

  openCategory(cat: Category) {
  const el = document.getElementById(cat._id as string);
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  } else {
    console.warn('Category element not found:', cat._id);
  }
}


  // ====================== CATEGORY METHODS ======================
  loadCategories() {
    this.loading.categories = true;

    this.categoryService.getAll().subscribe({
      next: (cats: any[]) => {
        this.categories = cats.map(cat => ({
          ...cat,
          _id: (cat._id as any)?.$oid || cat._id,
          userId: (cat.userId as any)?.$oid || cat.userId
        }));

        this.categories.forEach(cat => {
          const catId = cat._id || '';
          this.visibleCount[catId] = 6;
          if (catId) this.loadLinks(catId);
        });

        this.loading.categories = false;
      },
      error: (err) => {
        console.error('Failed to load categories:', err);
        this.loading.categories = false;
      }
    });

    this.loadAllLinks();
  }

  openAddCategoryDialog() {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, {
      width: '400px',
      data: { mode: 'create', name: '' }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.categoryService.create({ name: result.name }).subscribe({
          next: () => this.loadCategories(),
          error: (err) => console.error('Failed to create category:', err)
        });
      }
    });
  }

  openEditCategory(cat: Category) {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, {
      width: '400px',
      data: { mode: 'edit', name: cat.name, id: cat._id }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.categoryService.update(cat._id!, { name: result.name }).subscribe({
          next: () => this.loadCategories(),
          error: (err) => console.error('Failed to update category:', err)
        });
      }
    });
  }

  deleteCategory(cat: Category) {
    const catId = (cat._id as any)?.$oid || cat._id;
    if (!catId) return console.error('Missing category ID');

    if (confirm(`Delete category "${cat.name}"?`)) {
      this.categoryService.remove(catId).subscribe({
        next: () => {
          this.categories = this.categories.filter(c => ((c._id as any)?.$oid || c._id) !== catId);
          this.loadAllLinks();
        },
        error: (err) => console.error('Failed to delete category:', err)
      });
    }
  }

  // ====================== LINK METHODS ======================
  loadAllLinks() {
    this.linkService.getAll().subscribe({
      next: (res: any) => {
        const allLinks = [...(res.categorizedLinks || []), ...(res.uncategorizedLinks || [])];
        this.linksMap['all'] = allLinks.map(link => ({
          ...link,
          _id: (link._id as any)?.$oid || link._id,
          categoryId: (link.categoryId as any)?.$oid || link.categoryId
        }));
      },
      error: (err) => console.error('Failed to load all links:', err)
    });
  }

  loadLinks(categoryId: string) {
    this.loading.links[categoryId] = true;
    const fetch$ = categoryId === 'categorized'
      ? this.linkService.getByCategory('uncategorized')
      : this.linkService.getByCategory(categoryId);

    fetch$.subscribe({
      next: (links: any[]) => {
        this.linksMap[categoryId] = links.map(link => ({
          ...link,
          _id: (link._id as any)?.$oid || link._id,
          categoryId: (link.categoryId as any)?.$oid || link.categoryId
        }));
        this.loading.links[categoryId] = false;
      },
      error: (err) => {
        console.error(`Failed to load links for category ${categoryId}:`, err);
        this.loading.links[categoryId] = false;
      }
    });
  }

  visibleLinks(categoryId: string): Link[] {
    const allLinks = Array.isArray(this.linksMap[categoryId]) ? this.linksMap[categoryId] : [];
    return allLinks.slice(0, this.visibleCount[categoryId] || 6);
  }

  seeMore(categoryId: string) {
    this.visibleCount[categoryId] = (this.visibleCount[categoryId] || 6) + 6;
  }

  openAddLinkDialog(cat?: Category) {
    const dialogRef = this.dialog.open(AddLinkDialogComponent, {
      width: '400px',
      data: { mode: 'create', categoryId: cat?._id ?? null }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        const payload: any = {
          name: result.name,
          url: result.url,
          categoryId: result.categoryId ?? null
        };

        this.linkService.create(payload).subscribe({
          next: () => {
            this.loadAllLinks();
            if (result.categoryId) this.loadLinks(result.categoryId);
          },
          error: (err) => console.error('Failed to create link:', err)
        });
      }
    });
  }

  openEditLink(catId: string, link: Link) {
    const linkId = (link._id as any)?.$oid || link._id;

    const dialogRef = this.dialog.open(AddLinkDialogComponent, {
      width: '400px',
      data: { mode: 'edit', id: linkId, name: link.name, url: link.url, categoryId: catId }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        const payload: any = { name: result.name, url: result.url, categoryId: result.categoryId ?? null };
        this.linkService.update(linkId, payload).subscribe({
          next: () => {
            this.loadAllLinks();
            if (result.categoryId) this.loadLinks(result.categoryId);
            if (catId !== result.categoryId) this.loadLinks(catId);
          },
          error: (err) => console.error('Failed to update link:', err)
        });
      }
    });
  }

  deleteLink(catId: string, link: Link) {
    const linkId = (link._id as any)?.$oid || link._id;
    if (!linkId) return console.error('Missing link ID');

    if (confirm(`Delete link "${link.name}"?`)) {
      this.linkService.remove(linkId).subscribe({
        next: () => {
          this.loadAllLinks();
          this.loadLinks(catId);
        },
        error: (err) => console.error('Failed to delete link:', err)
      });
    }
  }
}
