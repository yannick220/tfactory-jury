T·Factory V45 — Pondérations cohérentes lors des pitchs sautés

1. Déployer tous les fichiers à la racine GitHub Pages.
2. Conserver les scripts SQL V43 puis V44 déjà installés. Aucun nouveau script SQL requis pour V45.
3. Une note cumulée n’utilise que les pitchs effectivement publiés, non sautés et déjà réalisés à la date du pitch affiché.
4. Les coefficients des familles de pitchs absentes sont renormalisés proportionnellement entre les familles présentes ; aucun zéro fictif ni pénalité artificielle.
5. Les financements cumulés ignorent les pitchs sautés, même si des données historiques verrouillées subsistent.
6. La valorisation reste : 10 × max(0, C × (1 + 5 × (N - moyenne)/moyenne)). Le pitch 6 (prêt) reste exclu du cumul C selon la règle existante.
7. Aucun enregistrement Supabase n’est modifié par cette mise à jour du code.
