-- =====================================================================
-- 1_creation.sql : MPD de la base NVIDIA (MySQL 8)
-- Création des tables avec les contraintes d'intégrité
--   - clés primaires (PRIMARY KEY)
--   - clés étrangères (FOREIGN KEY) avec ON UPDATE CASCADE et
--     ON DELETE CASCADE / SET NULL : la modification ou la suppression
--     d'une ligne référencée est répercutée automatiquement, sans erreur.
-- Les contraintes de validation (CHECK, UNIQUE, DEFAULT...) sont dans
-- 2_contraintes.sql.
-- =====================================================================

DROP DATABASE IF EXISTS nvidia_db;
CREATE DATABASE nvidia_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nvidia_db;

-- ---------------------------------------------------------------------
-- Entités indépendantes
-- ---------------------------------------------------------------------
CREATE TABLE DIVISION (
    id_division     INT            AUTO_INCREMENT,
    nom_division    VARCHAR(50)    NOT NULL,
    description     VARCHAR(255),
    CONSTRAINT pk_division PRIMARY KEY (id_division)
);

CREATE TABLE ARCHITECTURE (
    id_architecture   INT          AUTO_INCREMENT,
    nom_architecture  VARCHAR(50)  NOT NULL,
    annee_lancement   INT          NOT NULL,
    gravure_nm        INT          NOT NULL,
    CONSTRAINT pk_architecture PRIMARY KEY (id_architecture)
);

CREATE TABLE FONDERIE (
    id_fonderie   INT          AUTO_INCREMENT,
    nom_fonderie  VARCHAR(50)  NOT NULL,
    pays          VARCHAR(50)  NOT NULL,
    CONSTRAINT pk_fonderie PRIMARY KEY (id_fonderie)
);

CREATE TABLE TRIMESTRE (
    id_trimestre      INT  AUTO_INCREMENT,
    annee             INT  NOT NULL,
    numero_trimestre  INT  NOT NULL,
    CONSTRAINT pk_trimestre PRIMARY KEY (id_trimestre)
);

CREATE TABLE CLIENT (
    id_client       INT           AUTO_INCREMENT,
    raison_sociale  VARCHAR(100)  NOT NULL,
    type_client     VARCHAR(20)   NOT NULL,
    pays            VARCHAR(50)   NOT NULL,
    email_contact   VARCHAR(100)  NOT NULL,
    CONSTRAINT pk_client PRIMARY KEY (id_client)
);

CREATE TABLE PROJET_RD (
    id_projet   INT            AUTO_INCREMENT,
    nom_projet  VARCHAR(100)   NOT NULL,
    budget      DECIMAL(14,2)  NOT NULL,
    date_debut  DATE           NOT NULL,
    date_fin    DATE,
    CONSTRAINT pk_projet_rd PRIMARY KEY (id_projet)
);

-- ---------------------------------------------------------------------
-- EMPLOYE : appartient à une division + association réflexive DIRIGER
-- ---------------------------------------------------------------------
CREATE TABLE EMPLOYE (
    id_employe     INT            AUTO_INCREMENT,
    nom            VARCHAR(50)    NOT NULL,
    prenom         VARCHAR(50)    NOT NULL,
    email          VARCHAR(100)   NOT NULL,
    poste          VARCHAR(80)    NOT NULL,
    date_embauche  DATE           NOT NULL,
    salaire        DECIMAL(10,2)  NOT NULL,
    id_division    INT            NOT NULL,
    id_manager     INT            NULL,      -- réflexive : 0,1 manager
    CONSTRAINT pk_employe PRIMARY KEY (id_employe),
    CONSTRAINT fk_employe_division FOREIGN KEY (id_division)
        REFERENCES DIVISION(id_division)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_employe_manager FOREIGN KEY (id_manager)
        REFERENCES EMPLOYE(id_employe)
        ON UPDATE CASCADE ON DELETE SET NULL  -- le subordonné reste, sans manager
);

-- ---------------------------------------------------------------------
-- PRODUIT : repose sur une architecture, géré par une division
-- ---------------------------------------------------------------------
CREATE TABLE PRODUIT (
    id_produit       INT            AUTO_INCREMENT,
    nom_produit      VARCHAR(80)    NOT NULL,
    reference        VARCHAR(20)    NOT NULL,
    categorie        VARCHAR(20)    NOT NULL,
    date_sortie      DATE           NOT NULL,
    prix_lancement   DECIMAL(10,2)  NOT NULL,
    memoire_go       INT,
    tdp_watts        INT            NOT NULL,
    id_architecture  INT            NOT NULL,
    id_division      INT            NOT NULL,
    CONSTRAINT pk_produit PRIMARY KEY (id_produit),
    CONSTRAINT fk_produit_architecture FOREIGN KEY (id_architecture)
        REFERENCES ARCHITECTURE(id_architecture)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_produit_division FOREIGN KEY (id_division)
        REFERENCES DIVISION(id_division)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- REVISION : entité faible, identifiée relativement à PRODUIT
-- clé primaire composée (id_produit, code_revision)
-- ---------------------------------------------------------------------
CREATE TABLE REVISION (
    id_produit     INT           NOT NULL,
    code_revision  VARCHAR(5)    NOT NULL,
    date_revision  DATE          NOT NULL,
    description    VARCHAR(255),
    CONSTRAINT pk_revision PRIMARY KEY (id_produit, code_revision),
    CONSTRAINT fk_revision_produit FOREIGN KEY (id_produit)
        REFERENCES PRODUIT(id_produit)
        ON UPDATE CASCADE ON DELETE CASCADE   -- l'entité faible disparaît avec l'entité forte
);

-- ---------------------------------------------------------------------
-- FABRIQUER : association ternaire PRODUIT - FONDERIE - TRIMESTRE
-- ---------------------------------------------------------------------
CREATE TABLE FABRIQUER (
    id_produit         INT           NOT NULL,
    id_fonderie        INT           NOT NULL,
    id_trimestre       INT           NOT NULL,
    quantite_produite  INT           NOT NULL,
    cout_unitaire      DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_fabriquer PRIMARY KEY (id_produit, id_fonderie, id_trimestre),
    CONSTRAINT fk_fabriquer_produit FOREIGN KEY (id_produit)
        REFERENCES PRODUIT(id_produit)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_fabriquer_fonderie FOREIGN KEY (id_fonderie)
        REFERENCES FONDERIE(id_fonderie)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_fabriquer_trimestre FOREIGN KEY (id_trimestre)
        REFERENCES TRIMESTRE(id_trimestre)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- COMMANDE et CONTENIR (association porteuse COMMANDE - PRODUIT)
-- ---------------------------------------------------------------------
CREATE TABLE COMMANDE (
    id_commande    INT          AUTO_INCREMENT,
    date_commande  DATE         NOT NULL,
    statut         VARCHAR(20)  NOT NULL,
    id_client      INT          NOT NULL,
    CONSTRAINT pk_commande PRIMARY KEY (id_commande),
    CONSTRAINT fk_commande_client FOREIGN KEY (id_client)
        REFERENCES CLIENT(id_client)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE CONTENIR (
    id_commande    INT            NOT NULL,
    id_produit     INT            NOT NULL,
    quantite       INT            NOT NULL,
    prix_unitaire  DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_contenir PRIMARY KEY (id_commande, id_produit),
    CONSTRAINT fk_contenir_commande FOREIGN KEY (id_commande)
        REFERENCES COMMANDE(id_commande)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_contenir_produit FOREIGN KEY (id_produit)
        REFERENCES PRODUIT(id_produit)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- PARTICIPER : association porteuse EMPLOYE - PROJET_RD
-- ---------------------------------------------------------------------
CREATE TABLE PARTICIPER (
    id_employe  INT          NOT NULL,
    id_projet   INT          NOT NULL,
    role        VARCHAR(50)  NOT NULL,
    heures      INT          NOT NULL,
    CONSTRAINT pk_participer PRIMARY KEY (id_employe, id_projet),
    CONSTRAINT fk_participer_employe FOREIGN KEY (id_employe)
        REFERENCES EMPLOYE(id_employe)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_participer_projet FOREIGN KEY (id_projet)
        REFERENCES PROJET_RD(id_projet)
        ON UPDATE CASCADE ON DELETE CASCADE
);
