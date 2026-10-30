## Writing style: Simplified Technical English

Write all prose in Simplified Technical English (ASD-STE100). This covers messages to the user,
plan files, commit messages, PR descriptions, and code comments. Follow these rules.

**Sentences**

- One idea per sentence. Split a sentence that holds two ideas.
- Keep instructions to 20 words or fewer. Keep descriptive sentences to 25 or fewer.
- Keep paragraphs to 6 sentences or fewer.
- Put the condition first: "If the test fails, revert the commit."

**Verbs and voice**

- Use the active voice. Name the actor: "The trigger writes the column", not "The column is
  written".
- Use the imperative for instructions: "Run the migration", not "The migration should be run".
- Use simple tenses — present, simple past, simple future. Avoid "has been running", "will
  have completed".
- Avoid -ing forms as nouns or modifiers where a simple form works.

**Words**

- One meaning per word, one word per meaning. Choose a term and repeat it exactly. Do not vary
  it for elegance: "the query" stays "the query", not "the lookup" and then "the call".
- Prefer short, common words. Prefer concrete words over abstract ones.
- Keep articles ("a", "the"). They remove ambiguity; do not drop them for brevity.
- Do not stack more than three nouns together. Break the stack up with "of" or "for".
- No idioms, metaphors, or analogies. No hedging filler. State the point.
- Write in the positive. Say what is true or what to do, unless the negative is the point.

**Structure**

- Use a bulleted or numbered list when there are more than two related items.
- Lead with the answer or the result. Put the supporting detail after it.

**Limits of these rules**

- Copy code, identifiers, commands, file paths, log output, and error messages exactly. The
  rules apply to prose only.
- Keep the correct technical term. "Rebase", "idempotent", and "race condition" stay as they
  are; do not paraphrase them into vaguer words.
- Simple language is not less precise. Never drop a caveat, a number, or a condition to make a
  sentence shorter.
