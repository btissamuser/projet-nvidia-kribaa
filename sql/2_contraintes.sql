-- =====================================================================
-- 2_contraintes.sql : contraintes de validation (MySQL 8.0.16+)
-- Chaque contrainte est reliée à une règle métier (RGx) du README.
-- Types de contraintes couverts :
--   UNIQUE, NOT NULL, DEFAULT, CHECK (intervalle, liste IN, masque LIKE,
--   comparaison entre deux colonnes, condition composée)
-- =====================================================================
USE nvidia_db;

-- ------------------------- UNIQUE ------------------------------------
-- RG1 : deux divisions ne peuvent pas porter le même nom
ALTER TABLE DIVISION     ADD CONSTRAINT uq_division_nom      UNIQUE (nom_division);
-- RG8 : le nom d'une architecture est unique
ALTER TABLE ARCHITECTURE ADD CONSTRAINT uq_architecture_nom  UNIQUE (nom_architecture);
-- RG3 : l'email professionnel d'un employé est unique
ALTER TABLE EMPLOYE      ADD CONSTRAINT uq_employe_email     UNIQUE (email);
-- RG10 : la référence commerciale d'un produit est unique
ALTER TABLE PRODUIT      ADD CONSTRAINT uq_produit_reference UNIQUE (reference);
-- RG17 : un trimestre (année, numéro) n'existe qu'une seule fois
ALTER TABLE TRIMESTRE    ADD CONSTRAINT uq_trimestre         UNIQUE (annee, numero_trimestre);
-- RG16 : une fonderie est identifiée par son nom
ALTER TABLE FONDERIE     ADD CONSTRAINT uq_fonderie_nom      UNIQUE (nom_fonderie);

-- ------------------------- DEFAULT -----------------------------------
-- RG22 : une nouvelle commande est "En attente" par défaut
ALTER TABLE COMMANDE   ALTER statut SET DEFAULT 'En attente';
-- RG29 : un participant qui vient d'être affecté a 0 heure par défaut
ALTER TABLE PARTICIPER ALTER heures SET DEFAULT 0;

-- ------------------------- CHECK : intervalles -----------------------
-- RG4 : le salaire annuel brut est compris entre 30 000 et 1 000 000 $
ALTER TABLE EMPLOYE ADD CONSTRAINT ck_employe_salaire
    CHECK (salaire BETWEEN 30000 AND 1000000);
-- RG5 : NVIDIA a été fondée en 1993, aucune embauche avant cette date
ALTER TABLE EMPLOYE ADD CONSTRAINT ck_employe_date_embauche
    CHECK (date_embauche >= '1993-04-05');
-- RG9 : gravure entre 2 et 200 nm, lancement entre 1993 et 2030
ALTER TABLE ARCHITECTURE ADD CONSTRAINT ck_architecture_gravure
    CHECK (gravure_nm BETWEEN 2 AND 200);
ALTER TABLE ARCHITECTURE ADD CONSTRAINT ck_architecture_annee
    CHECK (annee_lancement BETWEEN 1993 AND 2030);
-- RG12 : prix strictement positif, TDP entre 1 et 2000 W, mémoire >= 0
ALTER TABLE PRODUIT ADD CONSTRAINT ck_produit_prix    CHECK (prix_lancement > 0);
ALTER TABLE PRODUIT ADD CONSTRAINT ck_produit_tdp     CHECK (tdp_watts BETWEEN 1 AND 2000);
ALTER TABLE PRODUIT ADD CONSTRAINT ck_produit_memoire CHECK (memoire_go IS NULL OR memoire_go >= 0);
-- RG17 : un trimestre est numéroté de 1 à 4
ALTER TABLE TRIMESTRE ADD CONSTRAINT ck_trimestre_numero
    CHECK (numero_trimestre BETWEEN 1 AND 4);
-- RG19 : quantité produite et coût unitaire strictement positifs
ALTER TABLE FABRIQUER ADD CONSTRAINT ck_fabriquer_quantite CHECK (quantite_produite > 0);
ALTER TABLE FABRIQUER ADD CONSTRAINT ck_fabriquer_cout     CHECK (cout_unitaire > 0);
-- RG24 : une ligne de commande porte sur au moins 1 unité, prix > 0
ALTER TABLE CONTENIR ADD CONSTRAINT ck_contenir_quantite CHECK (quantite >= 1);
ALTER TABLE CONTENIR ADD CONSTRAINT ck_contenir_prix     CHECK (prix_unitaire > 0);
-- RG27 : le budget d'un projet de R&D est strictement positif
ALTER TABLE PROJET_RD ADD CONSTRAINT ck_projet_budget CHECK (budget > 0);
-- RG29 : un employé ne peut pas déclarer plus de 2000 heures sur un projet
ALTER TABLE PARTICIPER ADD CONSTRAINT ck_participer_heures
    CHECK (heures BETWEEN 0 AND 2000);

-- ------------------------- CHECK : liste de valeurs (IN) -------------
-- RG11 : catégories de produit autorisées
ALTER TABLE PRODUIT ADD CONSTRAINT ck_produit_categorie
    CHECK (categorie IN ('GPU', 'Accelerateur', 'SoC', 'Superpuce', 'Reseau'));
-- RG20 : types de client autorisés
ALTER TABLE CLIENT ADD CONSTRAINT ck_client_type
    CHECK (type_client IN ('OEM', 'Cloud', 'Distributeur', 'Entreprise'));
-- RG22 : statuts de commande autorisés
ALTER TABLE COMMANDE ADD CONSTRAINT ck_commande_statut
    CHECK (statut IN ('En attente', 'Validee', 'Expediee', 'Livree', 'Annulee'));
-- RG28 : rôles possibles dans un projet
ALTER TABLE PARTICIPER ADD CONSTRAINT ck_participer_role
    CHECK (role IN ('Chef de projet', 'Ingenieur', 'Chercheur', 'Testeur', 'Designer'));

-- ------------------------- CHECK : masques (LIKE) --------------------
-- RG3 : l'email d'un employé est de la forme prenom.nom@nvidia.com
ALTER TABLE EMPLOYE ADD CONSTRAINT ck_employe_email
    CHECK (email LIKE '%_.%_@nvidia.com');
-- RG21 : l'email de contact d'un client contient un @ et un point après
ALTER TABLE CLIENT ADD CONSTRAINT ck_client_email
    CHECK (email_contact LIKE '%_@_%._%');
-- RG14 : un code de révision est une lettre majuscule suivie d'un chiffre
--        (A0, A1, B0...)
ALTER TABLE REVISION ADD CONSTRAINT ck_revision_code
    CHECK (code_revision REGEXP '^[A-Z][0-9]$');
-- RG10 : une référence produit commence par 2 lettres majuscules et un tiret
--        (ex : GF-4090, DC-H100)
ALTER TABLE PRODUIT ADD CONSTRAINT ck_produit_reference
    CHECK (reference REGEXP '^[A-Z]{2}-[A-Z0-9]+$');

-- ------------------------- CHECK : comparaison de colonnes -----------
-- RG26 : un projet ne peut pas se terminer avant d'avoir commencé
ALTER TABLE PROJET_RD ADD CONSTRAINT ck_projet_dates
    CHECK (date_fin IS NULL OR date_fin >= date_debut);
-- RG6 : un employé ne peut pas être son propre manager.
-- MySQL interdit un CHECK sur une colonne AUTO_INCREMENT (id_employe) ou sur
-- une colonne de clé étrangère ayant une action ON DELETE SET NULL
-- (id_manager). La règle est donc vérifiée par deux déclencheurs.
DROP TRIGGER IF EXISTS trg_employe_manager_ins;
DROP TRIGGER IF EXISTS trg_employe_manager_upd;
DELIMITER //
CREATE TRIGGER trg_employe_manager_ins BEFORE INSERT ON EMPLOYE
FOR EACH ROW
BEGIN
    IF NEW.id_manager IS NOT NULL AND NEW.id_manager = NEW.id_employe THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RG6 : un employe ne peut pas etre son propre manager';
    END IF;
END//
CREATE TRIGGER trg_employe_manager_upd BEFORE UPDATE ON EMPLOYE
FOR EACH ROW
BEGIN
    IF NEW.id_manager IS NOT NULL AND NEW.id_manager = NEW.id_employe THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RG6 : un employe ne peut pas etre son propre manager';
    END IF;
END//
DELIMITER ;

-- ------------------------- CHECK : condition composée ----------------
-- RG13 : un GPU ou un accélérateur possède obligatoirement de la mémoire
ALTER TABLE PRODUIT ADD CONSTRAINT ck_produit_memoire_gpu
    CHECK (categorie NOT IN ('GPU', 'Accelerateur') OR memoire_go > 0);
