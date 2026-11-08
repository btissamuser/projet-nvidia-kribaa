-- =====================================================================
-- 4_interrogation.sql : requêtes du scénario d'utilisation
--
-- Scénario : une analyste "Stratégie & Ventes" de NVIDIA prépare la revue
-- stratégique de fin d'année 2026 pour le comité de direction. Elle doit
-- extraire de la base : le catalogue et ses gammes, les ventes par client
-- et par segment, la production confiée aux fonderies, et l'organisation
-- des équipes de R&D. (Détail du scénario dans le README.)
-- =====================================================================
USE nvidia_db;

-- =====================================================================
-- PARTIE A : PROJECTIONS ET SELECTIONS
-- (tri, DISTINCT, masques LIKE, IN, BETWEEN)
-- =====================================================================

-- A1. Catalogue GeForce RTX 50 : nom, prix et consommation des cartes dont
--     la référence commence par "GF-50", de la plus chère à la moins chère.
SELECT nom_produit, prix_lancement, tdp_watts
FROM PRODUIT
WHERE reference LIKE 'GF-50%'
ORDER BY prix_lancement DESC;

-- A2. Liste des pays où NVIDIA a des clients (sans doublon), par ordre
--     alphabétique.
SELECT DISTINCT pays
FROM CLIENT
ORDER BY pays;

-- A3. Clients Cloud et Distributeurs basés en France ou en Suisse
--     (prospects pour la tournée commerciale européenne).
SELECT raison_sociale, type_client, pays
FROM CLIENT
WHERE type_client IN ('Cloud', 'Distributeur')
  AND pays IN ('France', 'Suisse')
ORDER BY type_client, raison_sociale;

-- A4. Produits sortis entre le 1er janvier 2023 et le 31 décembre 2024 et
--     vendus entre 1 000 et 40 000 $ (gamme "haut de gamme récent").
SELECT nom_produit, categorie, date_sortie, prix_lancement
FROM PRODUIT
WHERE date_sortie BETWEEN '2023-01-01' AND '2024-12-31'
  AND prix_lancement BETWEEN 1000 AND 40000
ORDER BY date_sortie;

-- A5. Employés dont le poste contient "Chercheur" ou "IA", embauchés
--     depuis 2015, triés par date d'embauche.
SELECT nom, prenom, poste, date_embauche
FROM EMPLOYE
WHERE (poste LIKE '%Chercheur%' OR poste LIKE '%IA%')
  AND date_embauche >= '2015-01-01'
ORDER BY date_embauche;

-- A6. Commandes qui ne sont pas encore livrées (en attente, validées ou
--     expédiées), de la plus récente à la plus ancienne.
SELECT id_commande, date_commande, statut
FROM COMMANDE
WHERE statut NOT IN ('Livree', 'Annulee')
ORDER BY date_commande DESC;

-- =====================================================================
-- PARTIE B : FONCTIONS D'AGREGATION (GROUP BY, HAVING)
-- =====================================================================

-- B1. Nombre de produits, prix moyen, minimum et maximum par catégorie.
SELECT categorie,
       COUNT(*)                     AS nb_produits,
       ROUND(AVG(prix_lancement),2) AS prix_moyen,
       MIN(prix_lancement)          AS prix_min,
       MAX(prix_lancement)          AS prix_max
FROM PRODUIT
GROUP BY categorie
ORDER BY nb_produits DESC;

-- B2. Chiffre d'affaires (hors commandes annulées) par année de commande.
SELECT YEAR(co.date_commande)                   AS annee,
       COUNT(DISTINCT co.id_commande)           AS nb_commandes,
       SUM(ct.quantite * ct.prix_unitaire)      AS chiffre_affaires
FROM COMMANDE co
JOIN CONTENIR ct ON ct.id_commande = co.id_commande
WHERE co.statut <> 'Annulee'
GROUP BY YEAR(co.date_commande)
ORDER BY annee;

-- B3. Clients ayant passé au moins 6 commandes (clients stratégiques).
SELECT id_client, COUNT(*) AS nb_commandes
FROM COMMANDE
GROUP BY id_client
HAVING COUNT(*) >= 6
ORDER BY nb_commandes DESC;

-- B4. Volume total produit par fonderie et par année, uniquement quand ce
--     volume dépasse 5 millions d'unités.
SELECT f.nom_fonderie, t.annee, SUM(fa.quantite_produite) AS volume_total
FROM FABRIQUER fa
JOIN FONDERIE  f ON f.id_fonderie  = fa.id_fonderie
JOIN TRIMESTRE t ON t.id_trimestre = fa.id_trimestre
GROUP BY f.nom_fonderie, t.annee
HAVING SUM(fa.quantite_produite) > 5000000
ORDER BY f.nom_fonderie, t.annee;

-- B5. Masse salariale, salaire moyen et effectif par division, pour les
--     divisions dont le salaire moyen dépasse 280 000 $.
SELECT d.nom_division,
       COUNT(e.id_employe)       AS effectif,
       SUM(e.salaire)            AS masse_salariale,
       ROUND(AVG(e.salaire), 0)  AS salaire_moyen
FROM DIVISION d
JOIN EMPLOYE  e ON e.id_division = d.id_division
GROUP BY d.nom_division
HAVING AVG(e.salaire) > 280000
ORDER BY salaire_moyen DESC;

-- B6. Nombre total d'heures et nombre de participants par projet de R&D
--     ayant mobilisé plus de 5 000 heures.
SELECT id_projet, COUNT(*) AS nb_participants, SUM(heures) AS total_heures
FROM PARTICIPER
GROUP BY id_projet
HAVING SUM(heures) > 5000
ORDER BY total_heures DESC;

-- =====================================================================
-- PARTIE C : JOINTURES (internes, externes, multiples, réflexive)
-- =====================================================================

-- C1. Jointure interne simple : chaque produit avec le nom de son
--     architecture et sa finesse de gravure.
SELECT p.nom_produit, a.nom_architecture, a.gravure_nm
FROM PRODUIT p
INNER JOIN ARCHITECTURE a ON a.id_architecture = p.id_architecture
ORDER BY a.annee_lancement, p.nom_produit;

-- C2. Jointure multiple (4 tables) : chiffre d'affaires par type de client
--     et par division de produit (hors commandes annulées).
SELECT cl.type_client, d.nom_division,
       SUM(ct.quantite * ct.prix_unitaire) AS chiffre_affaires
FROM CLIENT cl
JOIN COMMANDE co ON co.id_client   = cl.id_client
JOIN CONTENIR ct ON ct.id_commande = co.id_commande
JOIN PRODUIT  p  ON p.id_produit   = ct.id_produit
JOIN DIVISION d  ON d.id_division  = p.id_division
WHERE co.statut <> 'Annulee'
GROUP BY cl.type_client, d.nom_division
ORDER BY chiffre_affaires DESC;

-- C3. Jointure externe gauche : toutes les architectures avec leur nombre
--     de produits, y compris celles qui n'en ont encore aucun (Rubin).
SELECT a.nom_architecture, COUNT(p.id_produit) AS nb_produits
FROM ARCHITECTURE a
LEFT JOIN PRODUIT p ON p.id_architecture = a.id_architecture
GROUP BY a.id_architecture, a.nom_architecture
ORDER BY a.id_architecture;

-- C4. Jointure externe droite : toutes les fonderies, avec la quantité
--     totale qu'elles ont produite pour NVIDIA (0 si aucune).
SELECT f.nom_fonderie, f.pays,
       COALESCE(SUM(fa.quantite_produite), 0) AS quantite_totale
FROM FABRIQUER fa
RIGHT JOIN FONDERIE f ON f.id_fonderie = fa.id_fonderie
GROUP BY f.id_fonderie, f.nom_fonderie, f.pays
ORDER BY quantite_totale DESC;

-- C5. Auto-jointure (association réflexive DIRIGER) : chaque employé avec
--     le nom de son manager ("Aucun" pour la direction générale).
SELECT e.prenom, e.nom, e.poste,
       COALESCE(CONCAT(m.prenom, ' ', m.nom), 'Aucun') AS manager
FROM EMPLOYE e
LEFT JOIN EMPLOYE m ON m.id_employe = e.id_manager
ORDER BY e.id_manager IS NOT NULL, e.id_manager, e.nom;

-- C6. Jointure sur l'association ternaire : production des produits
--     Blackwell, par fonderie et par trimestre.
--     (Requête étudiée dans le README, partie "plans d'exécution")
SELECT p.nom_produit, f.nom_fonderie, t.annee, t.numero_trimestre,
       fa.quantite_produite
FROM ARCHITECTURE a
JOIN PRODUIT   p  ON p.id_architecture = a.id_architecture
JOIN FABRIQUER fa ON fa.id_produit     = p.id_produit
JOIN FONDERIE  f  ON f.id_fonderie     = fa.id_fonderie
JOIN TRIMESTRE t  ON t.id_trimestre    = fa.id_trimestre
WHERE a.nom_architecture = 'Blackwell'
ORDER BY p.nom_produit, t.annee, t.numero_trimestre;

-- C7. Requête du plan d'exécution (version simplifiée, 3 opérateurs :
--     sélection, jointure, projection) : nom des produits Blackwell et
--     quantités produites.
SELECT p.nom_produit, fa.quantite_produite
FROM ARCHITECTURE a
JOIN PRODUIT   p  ON p.id_architecture = a.id_architecture
JOIN FABRIQUER fa ON fa.id_produit     = p.id_produit
WHERE a.nom_architecture = 'Blackwell';

-- =====================================================================
-- PARTIE D : REQUETES IMBRIQUEES
-- ((NOT) IN, (NOT) EXISTS, ANY, ALL, sous-requête dans FROM)
-- =====================================================================

-- D1. IN : clients ayant commandé au moins une GeForce RTX 5090.
SELECT raison_sociale, type_client
FROM CLIENT
WHERE id_client IN (SELECT co.id_client
                    FROM COMMANDE co
                    JOIN CONTENIR ct ON ct.id_commande = co.id_commande
                    JOIN PRODUIT  p  ON p.id_produit   = ct.id_produit
                    WHERE p.nom_produit = 'GeForce RTX 5090')
ORDER BY raison_sociale;

-- D2. NOT IN : produits qui n'ont été fabriqués dans aucun trimestre
--     depuis 2023 (produits en fin de vie).
SELECT nom_produit, date_sortie
FROM PRODUIT
WHERE id_produit NOT IN (SELECT id_produit FROM FABRIQUER)
ORDER BY date_sortie;

-- D3. NOT EXISTS : clients qui n'ont jamais passé de commande
--     (à relancer par le service commercial).
SELECT cl.raison_sociale, cl.type_client, cl.pays
FROM CLIENT cl
WHERE NOT EXISTS (SELECT *
                  FROM COMMANDE co
                  WHERE co.id_client = cl.id_client);

-- D4. EXISTS : divisions qui possèdent au moins un produit de catégorie
--     SoC.
SELECT d.nom_division
FROM DIVISION d
WHERE EXISTS (SELECT *
              FROM PRODUIT p
              WHERE p.id_division = d.id_division
                AND p.categorie = 'SoC');

-- D5. > ALL : produits plus chers que tous les produits de la division
--     Gaming.
SELECT nom_produit, prix_lancement
FROM PRODUIT
WHERE prix_lancement > ALL (SELECT prix_lancement
                            FROM PRODUIT
                            WHERE id_division = 2)
ORDER BY prix_lancement;

-- D6. > ANY : employés de la division Gaming mieux payés qu'au moins un
--     employé de la division Data Center.
SELECT nom, prenom, salaire
FROM EMPLOYE
WHERE id_division = 2
  AND salaire > ANY (SELECT salaire FROM EMPLOYE WHERE id_division = 1)
ORDER BY salaire DESC;

-- D7. Sous-requête corrélée : produits vendus en moyenne plus cher que le
--     prix moyen de vente de leur catégorie.
SELECT p.nom_produit, p.categorie,
       ROUND(AVG(ct.prix_unitaire), 2) AS prix_vente_moyen
FROM PRODUIT p
JOIN CONTENIR ct ON ct.id_produit = p.id_produit
GROUP BY p.id_produit, p.nom_produit, p.categorie
HAVING AVG(ct.prix_unitaire) > (SELECT AVG(ct2.prix_unitaire)
                                FROM CONTENIR ct2
                                JOIN PRODUIT p2 ON p2.id_produit = ct2.id_produit
                                WHERE p2.categorie = p.categorie)
ORDER BY p.categorie, prix_vente_moyen DESC;

-- D8. Sous-requête dans le FROM : le client qui a généré le plus gros
--     chiffre d'affaires.
SELECT ca.raison_sociale, ca.total
FROM (SELECT cl.raison_sociale, SUM(ct.quantite * ct.prix_unitaire) AS total
      FROM CLIENT cl
      JOIN COMMANDE co ON co.id_client   = cl.id_client
      JOIN CONTENIR ct ON ct.id_commande = co.id_commande
      WHERE co.statut <> 'Annulee'
      GROUP BY cl.id_client, cl.raison_sociale) AS ca
WHERE ca.total = (SELECT MAX(t.total)
                  FROM (SELECT SUM(ct.quantite * ct.prix_unitaire) AS total
                        FROM COMMANDE co
                        JOIN CONTENIR ct ON ct.id_commande = co.id_commande
                        WHERE co.statut <> 'Annulee'
                        GROUP BY co.id_client) AS t);

-- D9. Projets de R&D sans aucun participant (NOT EXISTS).
SELECT nom_projet, date_debut, budget
FROM PROJET_RD pr
WHERE NOT EXISTS (SELECT * FROM PARTICIPER pa WHERE pa.id_projet = pr.id_projet);
