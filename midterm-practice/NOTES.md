# Midterm Practice -- Notes

## Task 5: git hygiene

Deleting the .tfstate file and the key in a new commit is not enough, because they are still in the old commits in the git history, so anyone with the repo can still read them; the key must be revoked and rotated, and the history must be cleaned.
