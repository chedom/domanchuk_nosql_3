// Крок 1. Знайдіть вузли з аномально великою кількістю ребер:
MATCH (n)
OPTIONAL MATCH (n)-[r]-()
WITH 
  n,
  labels(n) AS nodeLabels,
  count(r) AS degree
RETURN 
  nodeLabels,
  CASE
    WHEN n:User THEN toString(n.userId)
    WHEN n:Movie THEN n.title
    WHEN n:Genre THEN n.name
    ELSE 'Unknown'
  END AS nodeName,
  degree
ORDER BY degree DESC
LIMIT 50;