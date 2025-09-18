# Cake&Cost — чек-лист релиза

## ⚙️ Подготовка
- [ ] Внесены все изменения, протестированы
- [ ] Обновлена версия в `pubspec.yaml`
  - `version: MAJOR.MINOR.PATCH+BUILD`
  - `BUILD` (после `+`) увеличен
- [ ] Обновлён `CHANGELOG.md`

## ⚙️ Сборка и публикация
```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z+N"
git tag vX.Y.Z
git push origin main --tags
