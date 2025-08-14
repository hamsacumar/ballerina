import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDialog } from '@angular/material/dialog';
import { HeaderComponent } from '../shared/header/header.component';
import { FooterComponent } from '../shared/footer/footer.component';
import { AddCategoryDialogComponent } from '../shared/add-category-dialog/add-category-dialog.component';
import { AddLinkDialogComponent } from '../shared/add-link-dialog/add-link-dialog.component';
import { CategoryService } from '../service/category.service';
import { LinkService } from '../service/link.service';
import { Category } from '../model/category.model';
import { Link } from '../model/link.model';
import { MatMenuModule } from '@angular/material/menu';
@Component({
  selector: 'app-home',
  standalone: true,
  imports: [
    CommonModule,
    HeaderComponent,
    FooterComponent,
    MatButtonModule,
    MatIconModule,
      MatMenuModule, // <-- ADD THIS for mat-menu

        
  ],
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css']
})
export class HomeComponent implements OnInit {
    window = window; // now usable in template

  categories: Category[] = [];
  linksMap: Record<string, Link[]> = {};
  visibleCount: Record<string, number> = {};
  loading = { categories: false, links: {} as Record<string, boolean> };

  constructor(
    private dialog: MatDialog,
    private categoryService: CategoryService,
    private linkService: LinkService
  ) {}

  ngOnInit() {
    this.loadCategories();
    // Initialize "All" category visibleCount
    this.visibleCount['all'] = 6;
  }

  loadCategories() {
    this.loading.categories = true;
    this.categoryService.getAll().subscribe({
      next: (cats: Category[]) => {
        this.categories = cats;

        // Initialize visibleCount per category
        cats.forEach(cat => this.visibleCount[cat._id || ''] = 6);

        // Load links per category
        cats.forEach(cat => {
          if (cat._id) this.loadLinks(cat._id);
        });

        this.loading.categories = false;
      },
      error: () => { this.loading.categories = false; }
    });
  }

  loadLinks(categoryId: string) {
    this.loading.links[categoryId] = true;
    this.linkService.getByCategory(categoryId).subscribe({
      next: (links: Link[]) => {
        this.linksMap[categoryId] = links;
        this.loading.links[categoryId] = false;
      },
      error: () => { this.loading.links[categoryId] = false; }
    });
  }

  // Merge all links for "All" virtual category
  get allLinks(): Link[] {
    return Object.values(this.linksMap).flat();
  }

  visibleLinks(categoryId: string): Link[] {
    if (categoryId === 'all') return this.allLinks.slice(0, this.visibleCount['all'] || 6);
    return this.linksMap[categoryId]?.slice(0, this.visibleCount[categoryId] || 6) || [];
  }

  seeMore(categoryId: string) {
    this.visibleCount[categoryId] = (this.visibleCount[categoryId] || 6) + 6;
  }

  openAddCategoryDialog() {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, { width: '400px', data: { name: '' } });
    dialogRef.afterClosed().subscribe(result => {
      if (result) this.categoryService.create(result).subscribe(() => this.loadCategories());
    });
  }

  openEditCategory(cat: Category) {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, { width: '400px', data: { ...cat } });
    dialogRef.afterClosed().subscribe(result => {
      if (result) this.categoryService.update(cat._id || '', result).subscribe(() => this.loadCategories());
    });
  }

  deleteCategory(cat: Category) {
    if (confirm(`Delete category "${cat.name}"?`)) {
      this.categoryService.remove(cat._id || '').subscribe(() => this.loadCategories());
    }
  }

  // Add this to your component state
uncategorizedLinks: Link[] = [];

// Modify getAllLinks() method
get getAll(): Link[] {
  return [...this.uncategorizedLinks, ...Object.values(this.linksMap).flat()];
}



loadAllLinks() {
  this.linkService.getAll().subscribe({
    next: (links) => {
      // Separate uncategorized links
      this.uncategorizedLinks = links.filter(link => !link.categoryId);
      
      // Group categorized links
      this.categories.forEach(cat => {
        this.linksMap[cat._id!] = links.filter(link => 
          link.categoryId === cat._id
        );
      });
    }
  });
}

// Update openAddLinkDialog
openAddLinkDialog(cat?: Category) {
  const dialogRef = this.dialog.open(AddLinkDialogComponent, { 
    width: '400px',
    data: { 
      mode: 'create',
      categoryId: cat?._id 
    }
  });

  dialogRef.afterClosed().subscribe(result => {
    if (result) {
      this.linkService.create({
        name: result.name,
        url: result.url,
        categoryId: result.categoryId || undefined
      }).subscribe({
        next: () => {
          if (result.categoryId) {
            this.loadLinks(result.categoryId);
          } else {
            this.loadAllLinks(); // Refresh uncategorized links
          }
        },
        error: (err) => console.error('Error adding link', err)
      });
    }
  });
}
  
  openEditLink(catId: string, link: Link) {
    const dialogRef = this.dialog.open(AddLinkDialogComponent, { width: '400px', data: { ...link } });
    dialogRef.afterClosed().subscribe(result => {
      if (result) this.loadLinks(catId);
    });
  }

  deleteLink(catId: string, link: Link) {
    if (confirm(`Delete link "${link.name}"?`)) {
      this.linkService.remove(link._id || '').subscribe(() => this.loadLinks(catId));
    }
  }
}
