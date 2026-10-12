import Core

/// The pre-Phase-1 hard-coded candidate (CLAUDE.md §2), kept as a test fixture so gate and rubric
/// verdicts stay identical now that `Core` ships no personal profile.
extension CandidateProfile {
    static let fixture = CandidateProfile(
        regions: ["kazakhstan", "almaty", "gmt+5", "utc+5"],
        languages: ["english": "fluent", "russian": "native", "tatar": "native"],
        skills: SkillTiers(
            strong: ["python", "fastapi", "postgres*", "sqlalchemy", "sqlmodel", "alembic", "redis", "arq", "asyncio", "async",
                     "docker", "llm", "llms", "openai", "anthropic", "claude", "gemini", "gpt*", "prompt*", "eval", "evals",
                     "evaluation*", "rag", "retrieval", "embedding*", "vector", "semantic search", "mcp", "agent", "agents",
                     "agentic", "github actions", "ci cd", "azure*", "generative ai", "genai", "langchain", "llamaindex", "langgraph"],
            moderate: ["typescript", "react", "javascript", "node.js", "nodejs", "vllm", "ocr", "document processing", "gcp", "aws",
                       "lambda", "celery", "elasticsearch", "oauth*", "c#", ".net", "machine learning", "ml", "scikit learn",
                       "sklearn", "computer vision", "yolo*", "flask", "django", "graphql", "rest*", "api", "apis", "sql",
                       "microservice*", "linux", "git"],
            weak: ["fine tun*", "finetun*", "training", "pytorch", "tensorflow", "kubernetes", "k8s", "eks", "helm", "java",
                   "kotlin", "scala", "go", "golang", "rust", "mobile", "ios", "android", "swift", "spark", "flink", "databricks",
                   "kafka", "hadoop", "dbt", "airflow", "snowflake", "people management", "line management", "manage a team",
                   "managing a team", "team lead*", "terraform", "php", "ruby", "c++"]
        )
    )
}
