import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ForgotCodeComponent } from './forgot-code.component';

describe('ForgotCodeComponent', () => {
  let component: ForgotCodeComponent;
  let fixture: ComponentFixture<ForgotCodeComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ForgotCodeComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ForgotCodeComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
