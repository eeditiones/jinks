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
	it("should be able to open", () => {
		cy.get("pb-view-annotate").should("exist");
	});
});
