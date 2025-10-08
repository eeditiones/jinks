// We need a simple dateTime control that works with the timezoned dateTimes TEI works with
// TODO: Move to Fore?
window.customElements.define(
    "jinntap-datetime",
    class DateTimePicker extends HTMLElement {
        connectedCallback() {
            this.innerHTML = `
<input type="datetime-local" ></input>
`;
            this.control = this.firstElementChild;
            this.timezone = null;
            this.dateTimePart = "";

            this.defaultTimezone = this.getAttribute("data-default-timezone");
            //  this.control.addEventListener('change', (event) => {
            //      this.dispatchEvent('')
            // });
        }

        /**
         * @param {string} newValue
         */
        set value(newValue) {
            if (!newValue) {
                this.dateTimePart = "";
                this.timezone = this.defaultTimezone;
                return;
            }
            // An ISO dateTime is shaped like this:
            // yyyy-mm-ddThh:mm:ss.ss(+-)hh:mm
            const dateTimeRegex =
                /(?<date>\d\d\d\d-\d\d-\d\d)T(?<time>\d\d:\d\d:\d\d)(?<timezone>[+-]\d\d:\d\d)/;
            const { date, time, timezone } =
                dateTimeRegex.exec(newValue)?.groups ?? {};

            // Construct a new Date without the timezone info. Making it in the local timezone
            const jsDate = new Date(date + "T" + time);

            // But that date is in the locale timezone! toISOString pushes that to UTC, which might not be correct!
            // Add the local timezone offset to it
            jsDate.setMinutes(jsDate.getMinutes() - jsDate.getTimezoneOffset());
            // Finally, remove that trailing Z! datetime-local does not appreciate it! And! remove the milliseconds.
            this.dateTimePart = jsDate.toISOString().replace(/\.\d\d\dZ/, "");

            // And save that timezone. We need it later
            this.timezone = timezone;

            // Set the input to the datetime in the local timezone.
            this.control.value = this.dateTimePart;
        }

        /**
         * @returns {string}
         */
        get value() {
            const newValue = this.control.value;
            // Add the timezone again
            return `${newValue}${this.timezone ?? this.defaultTimezone}`;
        }
    },
);

/**
 * Panel for editing the metadata of the current document.
 *
 */
export class MetadataEditor {
    /**
     *  @param {import('jinn-tap').JinnTap} editor - The jinntap instance we're with
     *  @param {HTMLElement} panel - The host element for the metadata panel
     */
    constructor(editor, panel) {
        /**
         *  @type {import('jinn-tap').JinnTap}
         */
        this.editor = editor;

        /**
         * @type {HTMLElement}
         */
        this.panel = panel;

        /**
         * @private
         * @type {import('@jinntec/fore/src/fx-instance').FxInstance}
         */
        this._instance = this.panel.querySelector("#default");
        /**
         * @private
         * @type {import('@jinntec/fore/src/fx-fore').FxFore}
         */
        this._fore = this.panel.matches("fx-fore")
            ? this.panel
            : this.panel.querySelector("fx-fore");

        this.editor.addEventListener("ready", () =>
            setTimeout(() => this.update(), 1000),
        );

        this.update();
        this._fore.addEventListener(
            "refresh-done",
            this._onMetadataChange.bind(this),
        );

        const metadataPanelBtn = document.getElementById("metadataPanelBtn");

        metadataPanelBtn.addEventListener("click", () => {
            this.panel.classList.toggle("hidden");
        });
    }

    /**
     * Signal a new document, new metadata elements, and the form should be updated
     */
    update() {
        /**
         * @type {Document}
         */
        const document = this.editor.document;
        if (!document) {
            return;
        }
        const metadata = document.documentElement;

        this._instance.setInstanceData(metadata);
        this._fore.refresh(true);
        this._fore.querySelector("#on-init").perform();
    }

    _onMetadataChange() {
        this.editor.dispatchContentChange();
    }
}

document.addEventListener("DOMContentLoaded", () => {
    const editors = document.getElementsByTagName("jinn-tap");
    if (!editors.length) {
        return;
    }
    const metadataPanel = document.getElementById("metadata-panel");
    // Hide the panel initially
    metadataPanel.classList.add("hidden");

    const metadataEditor = new MetadataEditor(editors[0], metadataPanel);
});
