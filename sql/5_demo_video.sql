-- =====================================================================
-- 5_demo_video.sql : démonstrations pour la vidéo (partie modèle physique)
-- A exécuter instruction par instruction dans MySQL Workbench.
-- Les instructions marquées "ERREUR ATTENDUE" doivent être refusées.
-- =====================================================================
USE nvidia_db;

-- ---------------------------------------------------------------------
-- 1. Contenu de quelques tables
-- ---------------------------------------------------------------------
SELECT * FROM DIVISION;
SELECT * FROM PRODUIT LIMIT 10;
SELECT * FROM FABRIQUER LIMIT 10;
SELECT * FROM REVISION WHERE id_produit = 14;   -- entité faible : révisions de la RTX 5090

-- ---------------------------------------------------------------------
-- 2. Intégrité : insertions refusées
-- ---------------------------------------------------------------------
-- ERREUR ATTENDUE (clé primaire) : la division 1 existe déjà
INSERT INTO DIVISION VALUES (1, 'Cloud', 'Doublon de cle');

-- ERREUR ATTENDUE (clé étrangère) : l'architecture 99 n'existe pas
INSERT INTO PRODUIT VALUES (100, 'GeForce RTX 9090', 'GF-9090', 'GPU',
       '2027-01-01', 2499, 48, 600, 99, 2);

-- ERREUR ATTENDUE (CHECK IN) : catégorie inconnue
INSERT INTO PRODUIT VALUES (100, 'Console X', 'GF-CONSX', 'Console',
       '2027-01-01', 499, 16, 200, 8, 2);

-- ERREUR ATTENDUE (CHECK BETWEEN) : TDP de 5000 W
INSERT INTO PRODUIT VALUES (100, 'Radiateur', 'GF-HOT', 'GPU',
       '2027-01-01', 999, 16, 5000, 8, 2);

-- ERREUR ATTENDUE (CHECK LIKE) : email qui ne finit pas par @nvidia.com
INSERT INTO EMPLOYE VALUES (100, 'Test', 'Jean', 'jean.test@gmail.com',
       'Stagiaire', '2026-09-01', 40000, 2, 3);

-- ERREUR ATTENDUE (UNIQUE) : référence produit déjà utilisée
INSERT INTO PRODUIT VALUES (100, 'Copie 5090', 'GF-5090', 'GPU',
       '2027-01-01', 1999, 32, 575, 8, 2);

-- ERREUR ATTENDUE (CHECK sur 2 colonnes) : fin de projet avant le début
INSERT INTO PROJET_RD VALUES (100, 'Projet impossible', 1000000,
       '2026-06-01', '2026-01-01');

-- ERREUR ATTENDUE (déclencheur RG6) : employé manager de lui-même
UPDATE EMPLOYE SET id_manager = 10 WHERE id_employe = 10;

-- OK : valeur par défaut "En attente" appliquée au statut
INSERT INTO COMMANDE (id_commande, date_commande, id_client) VALUES (500, '2026-11-08', 20);
SELECT * FROM COMMANDE WHERE id_commande = 500;

-- ---------------------------------------------------------------------
-- 3. Modification / suppression d'une ligne référencée
-- ---------------------------------------------------------------------
-- ON UPDATE CASCADE : le produit 14 (RTX 5090) devient le produit 1014,
-- ses révisions, fabrications et lignes de commande suivent.
SELECT COUNT(*) AS lignes_contenir_14 FROM CONTENIR WHERE id_produit = 14;
UPDATE PRODUIT SET id_produit = 1014 WHERE id_produit = 14;
SELECT COUNT(*) AS lignes_contenir_1014 FROM CONTENIR  WHERE id_produit = 1014;
SELECT *                                FROM REVISION  WHERE id_produit = 1014;

-- ON DELETE CASCADE : supprimer un client supprime ses commandes et leurs lignes
SELECT COUNT(*) AS nb_commandes_ldlc FROM COMMANDE WHERE id_client = 20;
DELETE FROM CLIENT WHERE id_client = 20;
SELECT COUNT(*) AS nb_commandes_ldlc FROM COMMANDE WHERE id_client = 20;   -- 0

-- ON DELETE SET NULL (réflexive) : supprimer un manager ne supprime pas
-- ses subordonnés, leur id_manager devient NULL.
SELECT id_employe, nom, id_manager FROM EMPLOYE WHERE id_manager = 8;
DELETE FROM EMPLOYE WHERE id_employe = 8;
SELECT id_employe, nom, id_manager FROM EMPLOYE WHERE id_employe IN (19, 20);

-- Pour revenir à l'état initial : relancer 1_creation.sql, 2_contraintes.sql
-- puis 3_insertion.sql.
