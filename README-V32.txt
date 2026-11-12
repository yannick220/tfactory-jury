T·Factory V32 — correction affichage jury après connexion.
Cause identifiée dans V31 : fonctions toTen et euros absentes de jury.html, déclenchant une erreur JavaScript lors du rendu des équipes.
Correction : ajout des deux fonctions et suppression du libellé obsolète fourchette.
Aucune modification SQL nécessaire par rapport à V31. Les notes et les codes existants sont conservés.
Déployer jury.html sur GitHub ; si le navigateur conserve une version en cache, forcer son actualisation.
