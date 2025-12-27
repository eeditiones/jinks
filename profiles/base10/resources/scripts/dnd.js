
class PbDnd extends HTMLElement {

    constructor() {
        super();
        this.dragging = null;
    }

    connectedCallback() {
        this.dragSelector = this.getAttribute('drag');
        this.dropSelector = this.getAttribute('drop');

        document.addEventListener('dragstart', (ev) => this.dragStart(ev));
        document.addEventListener('dragover', (ev) => this.dragOver(ev));
        document.addEventListener('dragenter', (ev) => this.dragEnter(ev));
        document.addEventListener('dragleave', (ev) => this.dragLeave(ev));
        document.addEventListener('drop', (ev) => this.drop(ev));
    }

    dragStart(ev) {
        if (ev.target.matches(this.dragSelector)) {
            this.dragging = ev.target;
            ev.dataTransfer.effectAllowed = "move";
            ev.dataTransfer.setData("text/plain", ev.target.id); // fallback
        }
    }

    dragOver(ev) {
        const dropZone = ev.target.closest(this.dropSelector);
        if (dropZone && this.dragging) {
            ev.preventDefault();
            ev.dataTransfer.dropEffect = "move";
        }
    }

    dragEnter(ev) {
        const dropZone = ev.target.closest(this.dropSelector);
        if (dropZone && this.dragging) {
            ev.preventDefault();
            
            let counter = dropZone.__dragCounter || 0;
            counter++;
            dropZone.__dragCounter = counter;

            if (counter === 1) {
                dropZone.style.border = "var(--pb-dnd-drop-border)";
            }
        }
    }

    dragLeave(ev) {
        const dropZone = ev.target.closest(this.dropSelector);
        if (dropZone && this.dragging) {
            let counter = dropZone.__dragCounter || 0;
            counter--;
            
            if (counter <= 0) {
                counter = 0;
                dropZone.style.border = "";
            }
            dropZone.__dragCounter = counter;
        }
    }

    drop(ev) {
        const dropZone = ev.target.closest(this.dropSelector);
        if (dropZone && this.dragging) {
            ev.preventDefault();
            
            dropZone.style.border = "";
            dropZone.__dragCounter = 0;

            // Check if dropzone has content
            // We assume 'content' means element children that match the drag selector or just any element?
            // "If a element is dropped on a zone which already contains content, it should swap position with the existing element."
            // Let's assume the content is what we are dragging (or similar to it).
            // We'll treat the first element child of the dropzone as the content to swap.
            
            const existing = dropZone.firstElementChild;
            const originalParent = this.dragging.parentNode;

            if (existing && existing !== this.dragging) {
                // Swap
                // Move existing to where dragging was
                originalParent.appendChild(existing);
                dropZone.appendChild(this.dragging);
            } else {
                // Just move
                dropZone.appendChild(this.dragging);
            }

            this.dragging = null;
        }
    }
}

customElements.define('pb-dnd', PbDnd);
