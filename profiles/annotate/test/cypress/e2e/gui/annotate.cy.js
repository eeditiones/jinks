// Change these variables to make sense in your document
// The TEXT_TO_ANNOTATE should point to some name, organization, etcetera
const TEXT_TO_ANNOTATE = "Piet Heyn";
// What to annotate this as
const ANNOTATE_AS = "person";
// What attribute to use for annotations
const ANNOTATE_KEY = ANNOTATE_KEY;

/**
 * @param {HTMLElement} contents
 *
 * @returns {Text}
 */
function findTheTextNode(contents) {
	const textNode = contents.ownerDocument.evaluate(
		`descendant::text()[contains(., "${TEXT_TO_ANNOTATE}")]`,
		contents,
		null,
		XPathResult.FIRST_ORDERED_NODE_TYPE,
	);
	return textNode.singleNodeValue;
}

describe("Annotations", () => {
	beforeEach(() => {
		cy.login();

		cy.fixture("annotations.xml", "utf8").then((xml) => {
			cy.uploadXml("annotate/annotation.xml", xml).then(({ status, body }) => {
				cy.wrap(status).should("eq", 200);
				cy.wrap(body).its("path").should("include", "annotation.xml");
			});
		});

		cy.visit(
			"annotate/annotation.xml?template=annotate-tei.html&odd=annotations&view=div",
		);
	});
	it("should be able to open a file, make an annotation, save it, reload, and see it again", () => {
		cy.get("pb-view-annotate")
			.shadow()
			.find("#view")
			.should(
				"contain.text",
				TEXT_TO_ANNOTATE,
				"Sanity check: the text should be there,",
			)
			.then(([contents]) => {
				const document = contents.ownerDocument;
				const textNode = findTheTextNode(contents);

				const window = document.defaultView;
				window.getSelection().removeAllRanges();
				const range = document.createRange();
				const start = textNode.textContent.indexOf(TEXT_TO_ANNOTATE);
				const end = start + TEXT_TO_ANNOTATE.length;

				range.setStart(textNode, start);
				range.setEnd(textNode, end);
				window.getSelection().addRange(range);
				return cy.wrap(textNode.parentElement);
			})
			// Note: pb-view-annotate expects a click to 'end' a selection
			.scrollIntoView()
			.click();

		cy.get(`.annotation-action[data-type="${ANNOTATE_AS}"]`).click();

		cy.get("pb-authority-lookup")
			.shadow()
			.find('[title="link to"]')
			.first()
			.click();

		// Assert we actually got that annotation in

		cy.get("pb-view-annotate")
			.shadow()
			.find("#view")
			.should(([contents]) => {
				const textNode = findTheTextNode(contents);
				expect(textNode).to.exist;

				const annotation = textNode.parentElement.closest(".annotation");
				expect(annotation).to.exist;

				const annotationData = JSON.parse(
					annotation.getAttribute("data-annotation"),
				);
				expect(annotationData[ANNOTATE_KEY]).to.exist;
			});

		cy.get("#occurrences").find("li").last().find("mark").trigger("mouseenter");
		cy.get("pb-view-annotate").shadow().find("p").last().should("be.visible");

		cy.get("#mark-all").click();

		// Now, Save!
		cy.get("#document-save").click();

		cy.get("#commit [title='Merge and save annotations to TEI']").click();

		cy.get("#reload-all").click();

		// Annotation should stay
		cy.get("pb-view-annotate")
			.shadow()
			.find("#view")
			.should(([contents]) => {
				const textNode = findTheTextNode(contents);
				expect(textNode).to.exist;

				const annotation = textNode.parentElement.closest(".annotation");
				expect(annotation).to.exist;

				const annotationData = JSON.parse(
					annotation.getAttribute("data-annotation"),
				);
				expect(annotationData[ANNOTATE_KEY]).to.exist;
			});
	});
});
