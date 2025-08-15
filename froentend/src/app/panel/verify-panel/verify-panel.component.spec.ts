import { ComponentFixture, TestBed } from '@angular/core/testing';

import { VerifyPanelComponent } from './verify-panel.component';

describe('VerifyPanelComponent', () => {
  let component: VerifyPanelComponent;
  let fixture: ComponentFixture<VerifyPanelComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [VerifyPanelComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(VerifyPanelComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
