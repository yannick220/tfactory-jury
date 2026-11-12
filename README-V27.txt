T·Factory V27 — corrections depuis V26
1. Jury : saisie décimale libre entre 0 et 10 ; les notes récupérées sont affichées à deux décimales ; calcul du financement immédiat.
2. Administration : codes générés conservés dans le stockage local du navigateur utilisé par l’administrateur, même après fermeture et réouverture. Un renouvellement remplace le code local et invalide le précédent côté Supabase.
ATTENTION : les codes déjà perdus ne peuvent pas être retrouvés depuis les empreintes stockées dans Supabase. Les codes locaux ne sont PAS synchronisés entre appareils, navigateurs ou profils, et disparaissent si les données du navigateur sont effacées. Pour une conservation multi-appareils, il faudrait une évolution de la base avec accès administrateur sécurisé.
3. Les calculs de pondération et les données historiques ne sont pas modifiés.
Déploiement : remplacer les fichiers du site par ceux de cette archive. Aucun SQL supplémentaire nécessaire.
