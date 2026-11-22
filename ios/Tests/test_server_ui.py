"""iOS presentation contracts: no simulated SSH/telemetry, compact overview and tree."""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'Sources/DiakitwApp.swift').read_text()
assert 'Button("Обзор")' in s and 'Button("Серверы")' in s
assert 'Button("Все серверы")' in s and 'fleet.selection = nil' in s
assert 'ForEach(fleet.rows' in s and 'fleet.selection = row.profile.id' in s
for metric in ('row.cpu', 'row.ram', 'row.swap', 'row.disk'):
    assert metric in s
assert 'fleet.selected' in s and 'Изменить профиль' in s
assert 'TextField("IP-адрес или домен"' in s and 'TextField("SSH-порт"' in s and 'TextField("Логин"' in s
assert 'Сохранить профиль' in s and 'ServerProfiles.validate' in s
assert 'SSH-подключение недоступно' in s and 'Пароль и ключ не принимаются' in s
assert 'model.appRAM' in s and 'model.networkHistory' in s
assert 'title: "Батарея"' not in s
assert '192.0.2.10' not in s and 'Демо-данные' not in s
print('PASS iOS dashboard, fleet tree/list, editor and no fabricated connection')
