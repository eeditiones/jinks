describe("Annotations", () => {
	beforeEach(() => {
		cy.login();

		// Direct REST PUT, not cy.uploadXml(path, xmlContent): that command's actual signature
		// is (url, filename, xml, opts) - multipart, POSTs to an upload endpoint - so the old
		// 2-arg call silently posted to the literal path "annotate/annotation.xml" (405) rather
		// than writing the fixture anywhere.
		cy.fixture("annotations.xml", "utf8").then((xml) => {
			cy.request({
				method: "PUT",
				url: "http://localhost:8080/exist/rest/db/apps/tp-reconc/data/annotate/annotation.xml",
				auth: { username: "tei", password: "simple" },
				headers: { "Content-Type": "application/xml" },
				body: xml,
			}).then(({ status }) => {
				cy.wrap(status).should("be.oneOf", [200, 201]);
			});
		});

		// templates/pages/annotate.html is a base template with empty blocks (no
		// <pb-authority-lookup>, no annotation-toolbar content) - annotate-tei.html is what
		// actually fills them in and what real navigation links point at for a TEI document
		// (see templates/annotation-blocks.html's own link-building code).
		cy.visit(
			"annotate/annotation.xml?template=annotate-tei.html&odd=annotations&view=div",
		);
	});
	it("should be able to open", () => {
		cy.get("pb-view-annotate").should("exist");
	});
});
