/// A candidate's skill lexicon for `FitRubric`, split into strong / moderate / weak match areas.
/// Term syntax matches `FitRubric.matchedTerms`: whole words, a trailing `*` matches a word prefix.
public struct SkillTiers: Codable, Equatable, Sendable {
    public var strong: [String]
    public var moderate: [String]
    public var weak: [String]

    public init(strong: [String], moderate: [String], weak: [String]) {
        self.strong = strong
        self.moderate = moderate
        self.weak = weak
    }

    /// Generic tech-vocabulary catalog (union of every term the app knows how to spot). Not
    /// personal; a resume's tier assignment (`derived`) is what makes it a candidate's profile.
    public static let catalog: [String] = [
        "python", "fastapi", "postgres*", "sqlalchemy", "sqlmodel", "alembic", "redis", "arq", "asyncio", "async",
        "docker", "llm", "llms", "openai", "anthropic", "claude", "gemini", "gpt*", "prompt*", "eval", "evals",
        "evaluation*", "rag", "retrieval", "embedding*", "vector", "semantic search", "mcp", "agent", "agents",
        "agentic", "github actions", "ci cd", "azure*", "generative ai", "genai", "langchain", "llamaindex", "langgraph",
        "typescript", "react", "javascript", "node.js", "nodejs", "vllm", "ocr", "document processing", "gcp", "aws",
        "lambda", "celery", "elasticsearch", "oauth*", "c#", ".net", "machine learning", "ml", "scikit learn",
        "sklearn", "computer vision", "yolo*", "flask", "django", "graphql", "rest*", "api", "apis", "sql",
        "microservice*", "linux", "git",
        "fine tun*", "finetun*", "training", "pytorch", "tensorflow", "kubernetes", "k8s", "eks", "helm", "java",
        "kotlin", "scala", "go", "golang", "rust", "mobile", "ios", "android", "swift", "spark", "flink", "databricks",
        "kafka", "hadoop", "dbt", "airflow", "snowflake", "people management", "line management", "manage a team",
        "managing a team", "team lead*", "terraform", "php", "ruby", "c++",
    ]

    /// Tiers a resume into strong (3+ mentions), moderate (1-2) or weak (0) per catalog term.
    public static func derived(from resumeText: String, catalog: [String] = catalog) -> SkillTiers {
        var strong: [String] = [], moderate: [String] = [], weak: [String] = []
        for term in catalog {
            let count = FitRubric.termCount(resumeText, of: term)
            switch count {
            case 0: weak.append(term)
            case 1, 2: moderate.append(term)
            default: strong.append(term)
            }
        }
        return SkillTiers(strong: strong, moderate: moderate, weak: weak)
    }
}
