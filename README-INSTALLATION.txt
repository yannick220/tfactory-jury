T·FACTORY — V18 INDÉPENDANTE DE V17 — UN SEUL SUPABASE

1. NE MODIFIEZ PAS le dépôt GitHub V17. NE SUPPRIMEZ PAS son projet Supabase.
2. Dans le projet Supabase T-Factory existant, SQL Editor > New, collez le contenu de SUPABASE-V18-INDEPENDANTE.sql puis Run.
   Résultat attendu : nombre_equipes_v18 = 6.
3. Sur GitHub, créez un NOUVEAU dépôt distinct (ex. tfactory-jury).
4. Déposez les fichiers de cette archive à la RACINE de ce nouveau dépôt (pas dans un sous-dossier).
5. Activez Settings > Pages > Deploy from a branch > main > /(root).
6. Utilisez l'adresse du NOUVEAU dépôt pour tester la V18 ; l'ancien dépôt reste en V17.

Les données V18 sont copiées initialement depuis V17, puis indépendantes.
Les comptes administrateurs sont partagés ; les équipes, résultats, jurés, codes et publications sont séparés.
Ne pas exécuter les anciens scripts V18 sur les tables V17.

IMPORTANT : test réel de connexion Supabase requis. Les codes jurés à cinq chiffres ont une protection limitée.
