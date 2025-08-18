import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ChangepasswordPanelComponent } from './changepassword-panel.component';

describe('ChangepasswordPanelComponent', () => {
  let component: ChangepasswordPanelComponent;
  let fixture: ComponentFixture<ChangepasswordPanelComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ChangepasswordPanelComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ChangepasswordPanelComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
