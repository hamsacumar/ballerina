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
    MatMenuModule,
  ],
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css'],
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
  categoryIds: string[] = []; // Store IDs from printCategoryIds

  selectedLink: any;

  constructor(
    private dialog: MatDialog,
    private categoryService: CategoryService,
    private linkService: LinkService,
    private authService: AuthService,
    private searchService: SearchService
  ) { }

  // ====================== LIFECYCLE ======================

  ngOnInit() {
    console.log('ngOnInit started');
    this.visibleCount['all'] = 6;
    this.visibleCount['uncategorized'] = 6;

    this.loadCategories();
    this.linkService.getByCategory('68a3842a5e818329c71d1ea1');
    this.printCategoryIds();
    this.fetchCategories();

    // Somewhere in your component, e.g., ngOnInit or after loading categories
    this.categoryService.getAllIds().subscribe({
      next: (ids: string[]) => {
        console.log('All category IDs from service:', ids);
      },
      error: (err) => {
        console.error('Failed to fetch category IDs from service:', err);
      }
    });

    this.categoryService.getAll().subscribe({
      next: (cats: Category[]) => {
        console.log('All categories IDs22 from service:', cats);

        // Now get all IDs
        this.categoryService.getAllIds().subscribe({
          next: (ids: string[]) => console.log('All category IDs:', ids),
          error: (err) => console.error('Failed to fetch IDs:', err)
        });
      },
      error: (err) => console.error('Failed to fetch categories:', err)
    });



    this.authService.getProfile().subscribe({
      next: (profile) => console.log('User Profile:', profile),
      error: (err) => console.error('Failed to load profile:', err),
    });
  }

  fetchCategories() {
    this.categoryService.getAll().subscribe((data: Category[]) => {
      this.categories = data;
      console.log('Fetched categories:', this.categories);
    });
  }
  

  
  printCategoryIds() {
    console.log('Fetching category IDs...');

    // Use the service method that already extracts IDs
    this.categoryService.getAllIds().subscribe({
      next: (ids) => {
        console.log('Category IDs fetched:', ids);
        this.categoryIds = ids;

        // Load links for each category
        this.categoryIds.forEach(id => {
          if (id) {
            console.log('Loading links for category:', id);
            this.loadLinks(id);
          } else {
            console.warn('Category ID is undefined, skipping.');
          }
        });
      },
      error: (err) => console.error('Error fetching category IDs:', err)
    });
  }






  loadLinks(categoryId: string) {
    console.log(`Loading links for category: ${categoryId}`);
    this.loading.links[categoryId] = true;

    const fetch$ =
      categoryId === 'categorized'
        ? this.linkService.getByCategory('uncategorized')
        : this.linkService.getByCategory(categoryId);

    fetch$.subscribe({
      next: (links: any[]) => {
        console.log(`Links fetched for ${categoryId}:`, links);
        this.linksMap[categoryId] = links.map(link => ({
          ...link,
          _id: (link._id as any)?.$oid || link._id,
          categoryId: (link.categoryId as any)?.$oid || link.categoryId
        }));
        this.loading.links[categoryId] = false;
      },
      error: (err) => {
        console.error(`Failed to load links for category ${categoryId}:`, err);
      }
    });
  }

  loadCategories() {
    console.log('Loading categories...');
    this.loading.categories = true;

    this.categoryService.getAll().subscribe({
      next: (cats: any[]) => {
        console.log('Categories fetched:', cats);
        this.categories = cats.map(cat => ({
          ...cat,
          _id: (cat._id as any)?.$oid || cat._id,
          userId: (cat.userId as any)?.$oid || cat.userId
        }));

        console.log('Starting to load links for category IDs:', this.categoryIds);
        this.categoryIds.forEach(catId => {
          this.visibleCount[catId] = 6;
          if (catId) {
            this.loadLinks(catId);
          } else {
            console.warn('Invalid category ID:', catId);
          }
        });

        this.loading.categories = false;
      },
      error: (err) => {
        console.error('Failed to load categories:', err);
        this.loading.categories = false;
      },
    });

    this.loadAllLinks();
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


  openAddCategoryDialog() {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, {
      width: '400px',
      data: { mode: 'create', name: '' },
    });

    dialogRef.afterClosed().subscribe((result) => {
      if (result) {
        this.categoryService.create({ name: result.name }).subscribe({
          next: () => this.loadCategories(),
          error: (err) => console.error('Failed to create category:', err),
        });
      }
    });
  }

  openEditCategory(cat: Category) {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, {
      width: '400px',
      data: {
        mode: 'edit',
        id: this.getId(cat._id),
        name: cat.name,
      },
    });

    dialogRef.afterClosed().subscribe((result) => {
      if (result) {
        const categoryId = this.getId(cat._id);
        if (!categoryId) {
          console.error('Invalid category ID');
          return;
        }

        this.categoryService.update(categoryId, { name: result.name }).subscribe({
          next: () => this.loadCategories(),
          error: (err) => console.error('Failed to update category:', err),
        });
      }
    });
  }


  deleteCategory(cat: Category) {
    const categoryId = this.getId(cat._id);
    if (!categoryId) return console.error('Missing category ID');

    if (confirm(`Delete category "${cat.name}" and all its links?`)) {
      this.categoryService.remove(categoryId).subscribe({
        next: () => {
          this.categories = this.categories.filter(c => ((c._id as any)?.$oid || c._id) !== categoryId);
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



  visibleLinks(categoryId: string): Link[] {
    const allLinks = Array.isArray(this.linksMap[categoryId])
      ? this.linksMap[categoryId]
      : [];
    return allLinks.slice(0, this.visibleCount[categoryId] || 6);
  }

  seeMore(categoryId: string) {
    this.visibleCount[categoryId] = (this.visibleCount[categoryId] || 6) + 6;
  }

  /** Open dialog to add link (either under category or in ALL) */
  /** Open dialog to add link (either under category or in ALL) */
  openAddLinkDialog(cat?: Category) {
    const dialogRef = this.dialog.open(AddLinkDialogComponent, {
      width: '400px',
      data: {
        mode: 'create',
        categoryId: cat?._id ? this.getId(cat._id) : null,
      },
    });

    dialogRef.afterClosed().subscribe((result) => {
      if (result) {
        const payload: any = {
          name: result.name,
          url: result.url,
          categoryId: result.categoryId ?? null,
        };

        this.linkService.create(payload).subscribe({
          next: () => {
            this.loadAllLinks();
            if (result.categoryId) this.loadLinks(result.categoryId);
          },
          error: (err) => console.error('Failed to create link:', err),
        });
      }
    });
  }

  openEditLink(link: Link) {
    console.log('Editing link:', link); 
    console.log('Link ID:', link._id);
    const linkId = (link as any)._id || (link as any).id;  // fallback check
    console.log('Link ID:', linkId);
    const originalUrl = this.decodeUrl(link.hashedUrl);
    const dialogRef = this.dialog.open(AddLinkDialogComponent, {
      width: '400px',
      data: {
        mode: 'edit',
        id: linkId,
        name: link.name,
        url: originalUrl,
      },
    });
  
    dialogRef.afterClosed().subscribe((result) => {
      if (result) {
        const payload = {
          name: result.name,
          url: result.url,
        };
  
        this.linkService.update(linkId, payload).subscribe({
          next: () => {
            this.loadAllLinks();
          },
          error: (err) => console.error('Failed to update link:', err),
        });
      }
    });
  }
  

  deleteLink(catId: string, link: Link) {
    const linkId = (link._id as any)?.$oid || link._id;
    if (!linkId) return console.error('Missing link ID');
  
    if (!confirm(`Delete link "${link.name}"?`)) return;
  
    this.linkService.remove(linkId).subscribe({
      next: () => {
        console.log(`Link ${link.name} deleted`);
        this.loadLinks(catId); // pick only one reload
      },
      error: (err) => console.error('Failed to delete link:', err),
    });
  }
  

  
  
  // Add this method to your HomeComponent class
  decodeUrl(encodedUrl: string): string {
    try {
      return atob(encodedUrl); // Decode base64 to original URL
    } catch (error) {
      console.error('Failed to decode URL:', error);
      return 'https://google.com'; // Fallback URL
    }
  }

  // Helper method to safely extract ID from string or { $oid: string }
  public getId(id: string | { $oid: string } | undefined): string {
    if (!id) return '';
    return typeof id === 'string' ? id : id.$oid;
  }

  // Method to safely open links
  openLink(link: Link): void {
    const originalUrl = this.decodeUrl(link.hashedUrl);
    window.open(originalUrl, '_blank');
  }
}
