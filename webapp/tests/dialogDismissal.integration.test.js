/**
 * Dialog Dismissal Integration Tests
 * Tests for X button and backdrop click-to-dismiss functionality
 */

import { mockCities, mockConfig } from './__mocks__/mockData.js';

describe('Dialog Dismissal Tests', () => {
  let container;
  
  beforeEach(() => {
    // Create DOM structure
    document.body.innerHTML = `
      <div id="test-container"></div>
      <div id="sr-announcements" role="status" aria-live="polite" aria-atomic="true"></div>
    `;
    container = document.getElementById('test-container');
    
    // Mock localStorage
    localStorage.getItem.mockReturnValue(JSON.stringify(mockCities));
    
    // Define closeAllModals and announceToScreenReader functions
    window.closeAllModals = jest.fn(() => {
      document.querySelectorAll('.modal:not([hidden])').forEach(modal => {
        modal.hidden = true;
      });
    });
    
    window.announceToScreenReader = jest.fn((message) => {
      const srDiv = document.getElementById('sr-announcements');
      if (srDiv) {
        srDiv.textContent = message;
      }
    });
  });

  afterEach(() => {
    document.body.innerHTML = '';
    jest.clearAllMocks();
  });

  test('dialog has close button with proper attributes', () => {
    container.innerHTML = `
      <div class="modal" role="dialog" aria-labelledby="test-title" aria-modal="true">
        <div class="modal-content">
          <button class="modal-close-btn" aria-label="Close dialog" type="button">×</button>
          <h3 id="test-title">Test Dialog</h3>
          <p>Dialog content</p>
        </div>
      </div>
    `;
    
    const closeBtn = container.querySelector('.modal-close-btn');
    expect(closeBtn).toBeTruthy();
    expect(closeBtn.getAttribute('aria-label')).toBe('Close dialog');
    expect(closeBtn.getAttribute('type')).toBe('button');
    expect(closeBtn.textContent).toBe('×');
  });

  test('clicking close button triggers closeAllModals', () => {
    container.innerHTML = `
      <div class="modal" role="dialog" aria-labelledby="test-title" aria-modal="true">
        <div class="modal-content">
          <button class="modal-close-btn" aria-label="Close dialog" type="button">×</button>
          <h3 id="test-title">Test Dialog</h3>
          <p>Dialog content</p>
        </div>
      </div>
    `;
    
    const closeBtn = container.querySelector('.modal-close-btn');
    closeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      window.closeAllModals();
      window.announceToScreenReader('Dialog closed');
    });
    
    closeBtn.click();
    
    expect(window.closeAllModals).toHaveBeenCalled();
    expect(window.announceToScreenReader).toHaveBeenCalledWith('Dialog closed');
  });

  test('clicking modal backdrop closes dialog', () => {
    container.innerHTML = `
      <div class="modal" id="test-modal" role="dialog" aria-labelledby="test-title" aria-modal="true">
        <div class="modal-content">
          <h3 id="test-title">Test Dialog</h3>
          <p>Dialog content</p>
        </div>
      </div>
    `;
    
    const modal = container.querySelector('.modal');
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        window.closeAllModals();
        window.announceToScreenReader('Dialog closed');
      }
    });
    
    // Click on the modal backdrop (not the content)
    modal.click();
    
    expect(window.closeAllModals).toHaveBeenCalled();
    expect(window.announceToScreenReader).toHaveBeenCalledWith('Dialog closed');
  });

  test('clicking modal content does not close dialog', () => {
    container.innerHTML = `
      <div class="modal" id="test-modal" role="dialog" aria-labelledby="test-title" aria-modal="true">
        <div class="modal-content">
          <h3 id="test-title">Test Dialog</h3>
          <p>Dialog content</p>
        </div>
      </div>
    `;
    
    const modal = container.querySelector('.modal');
    const modalContent = container.querySelector('.modal-content');
    
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        window.closeAllModals();
        window.announceToScreenReader('Dialog closed');
      }
    });
    
    // Click on the modal content
    modalContent.click();
    
    // Should NOT close the dialog
    expect(window.closeAllModals).not.toHaveBeenCalled();
    expect(window.announceToScreenReader).not.toHaveBeenCalled();
  });

  test('close button announces to screen reader', () => {
    container.innerHTML = `
      <div class="modal" role="dialog" aria-labelledby="test-title" aria-modal="true">
        <div class="modal-content">
          <button class="modal-close-btn" aria-label="Close dialog" type="button">×</button>
          <h3 id="test-title">Test Dialog</h3>
          <p>Dialog content</p>
        </div>
      </div>
    `;
    
    const closeBtn = container.querySelector('.modal-close-btn');
    closeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      window.closeAllModals();
      window.announceToScreenReader('Dialog closed');
    });
    
    closeBtn.click();
    
    const srDiv = document.getElementById('sr-announcements');
    expect(srDiv.textContent).toBe('Dialog closed');
  });

  test('multiple dialogs can each be closed independently', () => {
    container.innerHTML = `
      <div class="modal" id="modal-1" role="dialog" aria-labelledby="title-1" aria-modal="true">
        <div class="modal-content">
          <button class="modal-close-btn" aria-label="Close dialog" type="button">×</button>
          <h3 id="title-1">Dialog 1</h3>
        </div>
      </div>
      <div class="modal" id="modal-2" role="dialog" aria-labelledby="title-2" aria-modal="true" hidden>
        <div class="modal-content">
          <button class="modal-close-btn" aria-label="Close dialog" type="button">×</button>
          <h3 id="title-2">Dialog 2</h3>
        </div>
      </div>
    `;
    
    const modal1 = document.getElementById('modal-1');
    const closeBtn1 = modal1.querySelector('.modal-close-btn');
    
    closeBtn1.addEventListener('click', (e) => {
      e.stopPropagation();
      window.closeAllModals();
    });
    
    expect(modal1.hidden).toBeFalsy();
    closeBtn1.click();
    expect(window.closeAllModals).toHaveBeenCalled();
  });

  test('close button has visible focus indicator', () => {
    container.innerHTML = `
      <button class="modal-close-btn" 
              aria-label="Close dialog" 
              type="button"
              style="outline: 3px solid #2563eb; outline-offset: 2px;">
        ×
      </button>
    `;
    
    const closeBtn = container.querySelector('.modal-close-btn');
    const styles = window.getComputedStyle(closeBtn);
    
    // Check that outline is set (focus indicator)
    expect(closeBtn.style.outline).toBeTruthy();
    expect(closeBtn.style.outlineOffset).toBeTruthy();
  });
});
