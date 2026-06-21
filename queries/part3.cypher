// Запит 1. Знайти всі фільми жанру «Thriller» із середнім рейтингом вище 4.0:
MATCH (g:Genre {name: "Thriller"})<-[:IN_GENRE]-(m:Movie)<-[r:RATED]-()
WITH m, avg(r.rating) AS avgRating
WHERE avgRating > 4.0
RETURN m.title AS MovieTitle, m.year AS ReleaseYear, round(avgRating, 2) AS AverageRating
ORDER BY avgRating DESC;

// Запит 2. Знайти користувачів, які поставили оцінку 5 більш ніж 50 фільмам:
MATCH (u:User)-[r:RATED]->(m:Movie)
WHERE r.rating = 5
WITH u, count(r) AS fiveStarRatings
WHERE fiveStarRatings > 50
RETURN u.userId AS UserID, fiveStarRatings AS FiveStarCount
ORDER BY fiveStarRatings DESC;

// Запит 3. Знайти фільми, які обидва користувачі (наприклад, userId=1 і userId=2) оцінили високо (рейтинг ≥ 4):
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.movieId AS MovieId, m.title AS MovieTitle, r1.rating AS RatingUser1, r2.rating AS RatingUser2;

// Запит 4. Знайти жанри, чиї фільми стабільно отримують високі оцінки — середній рейтинг і кількість оцінок:
MATCH (g:Genre)<-[:IN_GENRE]-(m:Movie)<-[r:RATED]-()
WITH g, avg(r.rating) AS avgRating, count(r) AS ratingCount
WHERE ratingCount >= 1000 AND avgRating >= 4.0 // Фільтруємо жанри з принаймні 1000 оцінок і середнім рейтингом ≥ 4.0
RETURN g.name AS GenreName, round(avgRating, 2) AS AverageRating, ratingCount AS TotalRatings
ORDER BY avgRating DESC;

// Запит 5. Рекомендація «користувачі зі схожими смаками також дивилися»: для заданого користувача знайти фільми, 
// які він ще не дивився, але високо оцінили користувачі з подібними смаками:
MATCH (target:User {userId: 1})-[r1:RATED]->(likedMovie:Movie)<-[r2:RATED]-(peer:User)
WHERE r1.rating >= 4
  AND r2.rating >= 4
  AND target <> peer
WITH target, peer, count(likedMovie) AS sharedMovies
WHERE sharedMovies >= 5 // Знаходимо схожих користувачів (хоча б 5 спільних фільмів)

MATCH (peer)-[r3:RATED]->(recommendedMovie:Movie)
WHERE r3.rating >= 4 AND NOT (target)-[:RATED]->(recommendedMovie) 

WITH recommendedMovie, avg(r3.rating) AS potentialRating, count(peer) AS peerCount
RETURN recommendedMovie.title AS RecommendedMovie, recommendedMovie.year AS Year, round(potentialRating, 2) AS AvgPeerRating, peerCount
ORDER BY peerCount DESC, potentialRating DESC
LIMIT 10;

// Запит 6. Знайти найкоротший ланцюжок зв’язку між двома користувачами через спільні фільми:
MATCH p = shortestPath((u1:User {userId: 1})-[:RATED*..5]-(u2:User {userId: 10}))
RETURN p;