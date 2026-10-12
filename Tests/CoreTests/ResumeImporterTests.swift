import Foundation
@testable import Core
import Testing

@Suite struct ResumeImporterTests {
    @Test func plainTextDecodesUTF8() throws {
        let text = try ResumeImporter.text(from: Data("Senior Engineer, Python, FastAPI".utf8), type: .plain)
        #expect(text.contains("FastAPI"))
    }

    @Test func pdfThrowsOnGarbageData() {
        #expect(throws: ResumeImportError.self) { try ResumeImporter.text(from: Data("not a pdf".utf8), type: .pdf) }
    }

    @Test func latexStripsCommandsCommentsAndPreamble() {
        let source = """
        \\documentclass{article}
        \\usepackage{geometry}
        % personal note, drop this line
        \\begin{document}
        \\section{Experience}
        \\textbf{Senior Engineer}, Acme Corp \\\\
        \\begin{itemize}
        \\item Built \\emph{Python} services with FastAPI
        \\item Led migration to Kubernetes
        \\end{itemize}
        \\end{document}
        """
        let text = ResumeImporter.strippedLaTeX(source)
        #expect(text.contains("Experience"))
        #expect(text.contains("Senior Engineer, Acme Corp"))
        #expect(text.contains("Built Python services with FastAPI"))
        #expect(!text.contains("\\"))
        #expect(!text.contains("%"))
        #expect(!text.contains("documentclass"))
    }

    @Test func fileExtensionMapsToTheRightType() {
        #expect(ResumeFileType(fileExtension: "pdf") == .pdf)
        #expect(ResumeFileType(fileExtension: "PDF") == .pdf)
        #expect(ResumeFileType(fileExtension: "tex") == .latex)
        #expect(ResumeFileType(fileExtension: "txt") == .plain)
        #expect(ResumeFileType(fileExtension: "md") == .plain)
    }
}
