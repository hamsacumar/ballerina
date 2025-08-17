import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PanelfooterComponent } from './panelfooter.component';

describe('PanelfooterComponent', () => {
  let component: PanelfooterComponent;
  let fixture: ComponentFixture<PanelfooterComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PanelfooterComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(PanelfooterComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
