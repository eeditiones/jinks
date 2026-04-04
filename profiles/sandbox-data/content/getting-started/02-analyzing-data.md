# Analyzing Data

The Mondial database is a geographic dataset compiled by the University of Göttingen, containing information about countries, cities, provinces, and religions. These examples demonstrate how to use FLWOR expressions to analyze structured XML data.

## Top Cities by Country

For each country, list the three cities with the highest population, sorted by country name:

<!-- context: data/mondial.xml -->
```xquery
for $country in /mondial/country
let $cities :=
    (for $city in $country//city[population]
    order by xs:integer($city/population[1]) descending
    return $city)
order by $country/name
return
    <country name="{$country/name}">
    {
        subsequence($cities, 1, 3)
    }
    </country>
```

This query uses a nested FLWOR expression: the inner loop sorts cities by population, and the outer loop iterates over countries. The `subsequence()` function picks just the top 3.

## Provinces and Cities

Find all Spanish provinces and their cities:

<!-- context: data/mondial.xml -->
```xquery
let $country := /mondial/country[name = 'Spain']
for $province in $country/province
order by $province/name
return
    <province>
        {$province/name}
        {
            for $city in $country//city[@province = $province/@id]
            order by $city/name
            return $city
        }
    </province>
```

This demonstrates joining data using attribute references — cities reference their province via the `@province` attribute, matched against the province's `@id`.

## Filtering with Quantified Expressions

Find the countries with the largest Roman Catholic population:

<!-- context: data/mondial.xml -->
```xquery
for $country in /mondial/country
where some $r in $country/religions satisfies $r = "Roman Catholic"
order by $country/religions[. = "Roman Catholic"]/@percentage cast as xs:double descending
return
    <country name="{$country/name}">
        {$country/religions}
    </country>
```

The `some ... satisfies` expression is a *quantified expression* — it returns true if at least one item in the sequence matches the condition. Results are sorted by the Catholic population percentage in descending order.
