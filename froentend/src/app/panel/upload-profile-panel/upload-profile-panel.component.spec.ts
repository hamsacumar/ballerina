import { ComponentFixture, TestBed } from '@angular/core/testing';

import { UploadProfilePanelComponent } from './upload-profile-panel.component';

describe('UploadProfilePanelComponent', () => {
  let component: UploadProfilePanelComponent;
  let fixture: ComponentFixture<UploadProfilePanelComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UploadProfilePanelComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(UploadProfilePanelComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
