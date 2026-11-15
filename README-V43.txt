T·Factory V43 — publication automatique des pitchs

IMPORTANT : exécuter SUPABASE-V43-PUBLICATION-AUTOMATIQUE.sql dans Supabase > SQL Editor AVANT de déployer les fichiers du site.

Le trigger serveur publie automatiquement un pitch lorsque chaque juré pro et pédagogique inscrit pour ce pitch a enregistré ses notes pour chaque équipe éligible. Le dernier enregistrement déclenche le calcul transactionnel des moyennes, financements, commentaires et verrouillage. Le Live (rafraîchissement automatique) voit alors les résultats sans clic administrateur.

Le SQL vérifie aussi les pitchs déjà complets lors de son installation. Les pitchs déjà publiés ne sont pas écrasés.

Le bouton de publication manuelle reste accessible comme recours exceptionnel.

Ne pas oublier : publier le ZIP seul sur GitHub ne peut pas installer un trigger dans Supabase.
