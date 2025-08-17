import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
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

// Models
import { Category } from '../model/category.model';
import { Link } from '../model/link.model';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [
    CommonModule,
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
  // Store categories & links
  categories: Category[] = [];
  linksMap: Record<string, Link[]> = {};  // { "all": [...], "catId1": [...], ... }
  visibleCount: Record<string, number> = {}; // { "all": 6, "catId1": 6, ... }

  // Loading flags
  loading = { categories: false, links: {} as Record<string, boolean> };

  // Make window accessible in template (for open link in new tab)
  window = window;

  constructor(
    private dialog: MatDialog,
    private categoryService: CategoryService,
    private linkService: LinkService,
    private authService: AuthService
  ) {}

  // ====================== LIFECYCLE ======================
  ngOnInit() {
    this.loadCategories();
    this.visibleCount['all'] = 6; // default visible count for "All"

    // Debug: fetch user profile (to confirm JWT works)
    this.authService.getProfile().subscribe({
      next: (profile) => console.log('User Profile:', profile),
      error: (err) => console.error('Failed to load profile:', err)
    });
  }

  // ====================== CATEGORY OPERATIONS ======================

  /** Load all categories for the logged-in user */
  loadCategories() {
    this.loading.categories = true;

    this.categoryService.getAll().subscribe({
      next: (cats: Category[]) => {
        this.categories = cats;

        // Init visible count + load links for each category
        cats.forEach(cat => {
          this.visibleCount[cat._id || ''] = 6;
          if (cat._id) this.loadLinks(cat._id);
        });

        this.loading.categories = false;
      },
      error: (err) => {
        console.error('Failed to load categories:', err);
        this.loading.categories = false;
      }
    });

    // Load "ALL" section separately
    this.loadAllLinks();
  }

  /** Open dialog to create a new category */
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

  /** Open dialog to edit category name */
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

  /** Delete category + its links */
  deleteCategory(cat: Category) {
    if (confirm(`Delete category "${cat.name}"?`)) {
      this.categoryService.remove(cat._id!).subscribe({
        next: () => this.loadCategories(),
        error: (err) => console.error('Failed to delete category:', err)
      });
    }
  }

  // ====================== LINK OPERATIONS ======================

  /** Load all links (for "ALL" section) */
/** Load all links (for "ALL" section) */
loadAllLinks() {
  this.linkService.getAll().subscribe({
    next: (res) => {
      // Combine categorized + uncategorized links into 'all'
      const allLinks = [
        ...(res.categorizedLinks || []),
        ...(res.uncategorizedLinks || [])
      ];
      this.linksMap['all'] = allLinks;
    },
    error: (err) => console.error('Failed to load all links:', err)
  });
}


  /** Load links for a specific category */
  loadLinks(categoryId: string) {
    this.loading.links[categoryId] = true;

    this.linkService.getByCategory(categoryId).subscribe({
      next: (links: Link[]) => {
        this.linksMap[categoryId] = Array.isArray(links) ? links : [];
        this.loading.links[categoryId] = false;
      },
      error: (err) => {
        console.error(`Failed to load links for category ${categoryId}:`, err);
        this.loading.links[categoryId] = false;
      }
    });
  }

  /** Return visible links with pagination */
  visibleLinks(categoryId: string): Link[] {
    const allLinks = Array.isArray(this.linksMap[categoryId]) ? this.linksMap[categoryId] : [];
    return allLinks.slice(0, this.visibleCount[categoryId] || 6);
  }

  /** Increase visible links counts */
  seeMore(categoryId: string) {
    this.visibleCount[categoryId] = (this.visibleCount[categoryId] || 6) + 6;
  }

  /** Open dialog to add link (either under category or in ALL) */
  openAddLinkDialog(cat?: Category) {
    const dialogRef = this.dialog.open(AddLinkDialogComponent, {
      width: '400px',
      data: { mode: 'create', categoryId: cat?._id || '' }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.linkService.create({
          name: result.name,
          url: result.url,
          categoryId: result.categoryId || null
        }).subscribe({
          next: () => {
            this.loadAllLinks();
            if (result.categoryId) this.loadLinks(result.categoryId);
          },
          error: (err) => console.error('Failed to create link:', err)
        });
      }
    });
  }

  /** Open dialog to edit existing link */
  openEditLink(catId: string, link: Link) {
    const dialogRef = this.dialog.open(AddLinkDialogComponent, {
      width: '400px',
      data: { mode: 'edit', id: link._id, name: link.name, url: link.url, categoryId: catId }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.linkService.update(link._id!, {
          name: result.name,
          url: result.url,
          categoryId: result.categoryId
        }).subscribe({
          next: () => {
            this.loadAllLinks();
            this.loadLinks(catId);
          },
          error: (err) => console.error('Failed to update link:', err)
        });
      }
    });
  }

  /** Delete link from category + "ALL" */
  deleteLink(catId: string, link: Link) {
    if (confirm(`Delete link "${link.name}"?`)) {
      this.linkService.remove(link._id!).subscribe({
        next: () => {
          this.loadAllLinks();
          this.loadLinks(catId);
        },
        error: (err) => console.error('Failed to delete link:', err)
      });
    }
  }
}
