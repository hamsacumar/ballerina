import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDialog } from '@angular/material/dialog';
import { MatMenuModule } from '@angular/material/menu';

import { HeaderComponent } from '../shared/header/header.component';
import { FooterComponent } from '../shared/footer/footer.component';
import { AddCategoryDialogComponent } from '../shared/add-category-dialog/add-category-dialog.component';
import { AddLinkDialogComponent } from '../shared/add-link-dialog/add-link-dialog.component';

import { CategoryService } from '../service/category.service';
import { LinkService } from '../service/link.service';
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
  window = window;

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
    this.visibleCount['all'] = 6; // All section
  }

  loadCategories() {
    this.loading.categories = true;
    this.categoryService.getAll().subscribe({
      next: (cats: Category[]) => {
        this.categories = cats;
        cats.forEach(cat => {
          this.visibleCount[cat._id || ''] = 6;
          if (cat._id) this.loadLinks(cat._id);
        });
        this.loading.categories = false;
      },
      error: () => { this.loading.categories = false; }
    });

    // Load all links for "ALL" section
    this.loadAllLinks();
  }

  loadAllLinks() {
    this.linkService.getAll().subscribe({
      next: (links: Link[]) => {
        this.linksMap['all'] = links;
      }
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

  visibleLinks(categoryId: string): Link[] {
    return this.linksMap[categoryId]?.slice(0, this.visibleCount[categoryId] || 6) || [];
  }

  seeMore(categoryId: string) {
    this.visibleCount[categoryId] = (this.visibleCount[categoryId] || 6) + 6;
  }

  openAddCategoryDialog() {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, { 
      width: '400px', 
      data: { mode: 'create', name: '' } 
    });
    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.categoryService.create({ name: result.name }).subscribe(() => this.loadCategories());
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
        this.categoryService.update(cat._id!, { name: result.name }).subscribe(() => this.loadCategories());
      }
    });
  }

  deleteCategory(cat: Category) {
    if (confirm(`Delete category "${cat.name}"?`)) {
      this.categoryService.remove(cat._id!).subscribe(() => this.loadCategories());
    }
  }

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
        }).subscribe(() => {
          this.loadAllLinks();
          if (result.categoryId) this.loadLinks(result.categoryId);
        });
      }
    });
  }

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
        }).subscribe(() => {
          this.loadAllLinks();
          this.loadLinks(catId);
        });
      }
    });
  }

  deleteLink(catId: string, link: Link) {
    if (confirm(`Delete link "${link.name}"?`)) {
      this.linkService.remove(link._id!).subscribe(() => {
        this.loadAllLinks();
        this.loadLinks(catId);
      });
    }
  }
}
