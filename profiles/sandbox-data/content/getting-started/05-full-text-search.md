# Full-Text Search

eXist-db includes a powerful full-text search engine based on Apache Lucene. The `ft:query()` function lets you search indexed text with support for phrases, proximity queries, and relevance scoring.

> **Note:** These examples require that the Shakespeare data has a Lucene full-text index configured. The Sandbox app sets this up automatically.

## Simple Word Search

Find speeches where Juliet talks about love:

<!-- context: data/shakespeare -->
```xquery
//SPEECH[ft:query(., 'love')][SPEAKER = "JULIET"]
```

The `ft:query()` function searches the full-text index. Unlike `contains()`, it understands word boundaries and is much faster on large datasets.

## Phrase Search

Search for an exact phrase by enclosing it in double quotes:

<!-- context: data/shakespeare -->
```xquery
//SPEECH[ft:query(., '"fenny snake"')]
```

This finds the exact phrase "fenny snake" — not just documents containing both words separately.

## Proximity Search

Find speeches where "love" and "father" occur within 20 words of each other, using Lucene's XML query syntax:

<!-- context: data/shakespeare -->
```xquery
let $query :=
    <query>
        <near slop="20"><term>love</term><near>father</near></near>
    </query>
return //SPEECH[ft:query(., $query)]
```

The `slop` attribute controls the maximum distance between the terms. This is useful for finding conceptual associations between words.

## Scoring and Relevance

Search results can be ranked by relevance using `ft:score()`:

<!-- context: data/shakespeare -->
```xquery
for $m in //SPEECH[ft:query(., "boil bubble")]
let $score := ft:score($m)
order by $score descending
return <m score="{$score}">{$m}</m>
```

Higher scores indicate a better match. Ordering by score descending puts the most relevant results first.
