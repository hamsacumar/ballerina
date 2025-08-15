import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ForgotpasswordPanelComponent } from './forgotpassword-panel.component';

describe('ForgotpasswordPanelComponent', () => {
  let component: ForgotpasswordPanelComponent;
  let fixture: ComponentFixture<ForgotpasswordPanelComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ForgotpasswordPanelComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ForgotpasswordPanelComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
