import XCTest

/// Klikt met echte tikken door de profieleditor: aanmaken met naam, kleur
/// en symbool, hernoemen en weer verwijderen. De rooktest voor de flow die
/// een kind als eerste tegenkomt. Met RENDER_OUTPUT_DIR gezet bewaart hij
/// van elke stap een schermafbeelding.
final class ProfileEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateEditAndDeleteProfile() throws {
        let app = XCUIApplication()
        app.launch()

        // Naar de profielenlijst; op het startscherm is de tegel de enige
        // met deze tekst.
        app.staticTexts["Profielen"].firstMatch.tap()
        // Restanten van een eerdere (mislukte) run eerst opruimen, zodat
        // de test ook na een onderbreking betrouwbaar blijft.
        deleteProfileIfPresent(app, name: "Kapitein Nemo")
        deleteProfileIfPresent(app, name: "Matroos Mila")
        saveScreenshot("1-profielen.png")

        // Nieuw profiel: naam typen, kleur en symbool kiezen.
        app.buttons["Nieuw profiel"].tap()
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Kapitein Nemo")
        app.buttons["Kleur Mint"].tap()
        app.buttons["Ster"].tap()
        saveScreenshot("2-editor-nieuw.png")
        app.buttons["Klaar!"].tap()

        // De rij staat in de lijst.
        XCTAssertTrue(app.staticTexts["Kapitein Nemo"].waitForExistence(timeout: 3))
        saveScreenshot("3-profiel-aangemaakt.png")

        // Bewerken: naam vervangen, andere kleur.
        app.buttons["Profiel van Kapitein Nemo aanpassen"].firstMatch.tap()
        let editField = app.textFields.firstMatch
        XCTAssertTrue(editField.waitForExistence(timeout: 3))
        // Achteraan tikken en terugwissen: zo is de cursorpositie zeker.
        editField.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        editField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        editField.typeText("Matroos Mila")
        app.buttons["Kleur Paars"].tap()
        saveScreenshot("4-editor-bewerken.png")
        app.buttons["Klaar!"].tap()

        XCTAssertTrue(app.staticTexts["Matroos Mila"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Kapitein Nemo"].exists)
        saveScreenshot("5-profiel-hernoemd.png")

        // Verwijderen, met de bevestiging ertussen.
        app.buttons["Matroos Mila verwijderen"].firstMatch.tap()
        let confirm = app.buttons["Verwijderen"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        saveScreenshot("6-verwijderen-bevestiging.png")
        confirm.tap()

        XCTAssertTrue(waitForDisappearance(of: app.staticTexts["Matroos Mila"]))
        saveScreenshot("7-profiel-verwijderd.png")
    }

    private func deleteProfileIfPresent(_ app: XCUIApplication, name: String) {
        while app.buttons["\(name) verwijderen"].firstMatch.exists {
            app.buttons["\(name) verwijderen"].firstMatch.tap()
            let confirm = app.buttons["Verwijderen"]
            guard confirm.waitForExistence(timeout: 3) else { return }
            confirm.tap()
            // Even laten landen voor de volgende ronde van de lus.
            _ = app.buttons["Nieuw profiel"].waitForExistence(timeout: 3)
        }
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func saveScreenshot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["RENDER_OUTPUT_DIR"] else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: dir, isDirectory: true).appendingPathComponent(name))
    }
}
