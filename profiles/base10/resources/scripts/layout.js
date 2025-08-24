function addResizeHandler(resizeContainer, elementsToResize, direction) {
    const resizeData = {
        tracking: false,
        startWidth: null,
        startCursorScreenX: null,
    };

    const handler = document.createElement("div");
    handler.classList.add("resize-handler");
    if (direction === "left") {
        resizeContainer.appendChild(handler);
    } else {
        resizeContainer.insertBefore(
            handler,
            resizeContainer.firstElementChild,
        );
    }

    handler.addEventListener("mousedown", (event) => {
        if (event.button !== 0) {
            return;
        }

        event.preventDefault();
        event.stopPropagation();

        resizeData.startWidth = parseFloat(
            getComputedStyle(resizeContainer).getPropertyValue("width"),
        );
        resizeData.startCursorScreenX = event.screenX;
        resizeData.tracking = true;
        resizeData.handler = handler;
        handler.classList.add("active");
        console.log("resize started");
    });

    window.addEventListener("mousemove", (event) => {
        if (!resizeData.tracking) {
            return;
        }
        const cursorScreenXDelta =
            event.screenX - resizeData.startCursorScreenX;
        const newWidth =
            resizeData.startWidth +
            cursorScreenXDelta * (direction === "left" ? 1 : -1);

        elementsToResize.forEach((t) => (t.style.width = `${newWidth}px`));
    });

    window.addEventListener("mouseup", () => {
        if (!resizeData.tracking) {
            return;
        }
        resizeData.tracking = false;

        handler.classList.remove("active");
    });
}

function setUpResizeContainers() {
    const container = document.body.querySelector("pb-page");
    // Setup for left
    const [beforeTop, before] = container.querySelectorAll(
        ".before-top,.before",
    );

    addResizeHandler(before, [beforeTop, before], "left");

    const [afterTop, after] = container.querySelectorAll(".after-top,.after");
    addResizeHandler(after, [afterTop, after], "right");
}

document.addEventListener("DOMContentLoaded", function () {
    // hide/expand the before and after sidebars
    const asideToggles = document.querySelectorAll(".aside-toggle");
    asideToggles.forEach((toggle) => {
        toggle.addEventListener("click", function () {
            const target = this.dataset.toggle;
            const targetElement = document.querySelector(target);
            targetElement.classList.toggle("hidden");
            this.closest(".before-top,.after-top").classList.toggle("hidden");
        });
    });

    // hide/expand mobile menu
    const mobileMenuToggle = document.querySelector(".mobile.trigger button");
    mobileMenuToggle.addEventListener("click", function () {
        const target = this.dataset.toggle;
        const targetElement = document.querySelector(target);
        targetElement.classList.toggle("hidden");
    });

    setUpResizeContainers();
});
