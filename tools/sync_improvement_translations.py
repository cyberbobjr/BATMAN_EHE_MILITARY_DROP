"""Install the retained improvements' translation keys, preserving existing strings."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'Contents/mods'
LANGS = ['EN', 'FR', 'DE', 'ES', 'PT', 'RU', 'CN']

def update(root, filename, rows, prefix):
    for index, language in enumerate(LANGS):
        targets = [language, 'PTBR'] if language == 'PT' else [language]
        for target in targets:
            path = root / target / (filename + '.json')
            values = json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else {}
            for key, translations in rows.items():
                values[prefix + key] = translations[index]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(values, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')

base = ROOT / 'batman_MilitaryDrop/42.21/media/lua/shared/Translate'
rows = {
 'AdminPhase_pending': ['Pending', 'En attente', 'Ausstehend', 'Pendiente', 'Pendente', 'Ожидается', '待发'],
 'AdminPhase_delivered': ['Delivered', 'Livré', 'Geliefert', 'Entregado', 'Entregue', 'Доставлен', '已交付'],
 'AdminMission_recon': ['Reconnaissance', 'Reconnaissance', 'Aufklärung', 'Reconocimiento', 'Reconhecimento', 'Разведка', '侦察'],
 'AdminMission_control': ['Check-in', 'Appel de contrôle', 'Kontrollanruf', 'Control de enlace', 'Controlo de ligação', 'Проверка связи', '通信检查'],
 'AdminMission_cleanup': ['Clearance', 'Nettoyage', 'Säuberung', 'Limpieza', 'Limpeza', 'Зачистка', '清剿'],
 'AdminDashboard': ['Operations', 'Opérations', 'Einsätze', 'Operaciones', 'Operações', 'Операции', '行动管理'],
 'AdminSuccess': ['Operation completed.', 'Opération effectuée.', 'Vorgang abgeschlossen.', 'Operación completada.', 'Operação concluída.', 'Операция выполнена.', '操作完成。'],
 'AdminUnchanged': ['No change: target unavailable or already processed.', 'Aucun changement : cible indisponible ou déjà traitée.', 'Keine Änderung: Ziel nicht verfügbar oder bereits bearbeitet.', 'Sin cambios: objetivo no disponible o ya procesado.', 'Sem alterações: alvo indisponível ou já processado.', 'Без изменений: цель недоступна или уже обработана.', '无变更：目标不可用或已处理。'],
 'AdminKind_drop': ['Drop', 'Largage', 'Abwurf', 'Entrega', 'Entrega', 'Сброс', '空投'],
 'AdminKind_flight': ['Flight', 'Vol', 'Flug', 'Vuelo', 'Voo', 'Полёт', '航班'],
 'AdminKind_wreck': ['Wreck', 'Épave', 'Wrack', 'Restos', 'Destroços', 'Обломки', '残骸'],
 'AdminKind_mission': ['Mission', 'Mission', 'Auftrag', 'Misión', 'Missão', 'Задание', '任务'],
 'AdminKind_character': ['Character / trust', 'Personnage / confiance', 'Charakter / Vertrauen', 'Personaje / confianza', 'Personagem / confiança', 'Персонаж / доверие', '角色 / 信任'],
 'Admin_Refresh': ['Refresh', 'Actualiser', 'Aktualisieren', 'Actualizar', 'Atualizar', 'Обновить', '刷新'],
 'Admin_Unlock': ['Restore line', 'Rétablir la ligne', 'Funk freigeben', 'Restaurar enlace', 'Restaurar ligação', 'Открыть связь', '恢复通信'],
 'Admin_CloseDrop': ['Cancel pending drop', 'Annuler le largage', 'Abwurf abbrechen', 'Cancelar entrega', 'Cancelar entrega', 'Отменить сброс', '取消待发空投'],
 'Admin_Announce': ['Repeat broadcast', 'Répéter l’annonce', 'Meldung wiederholen', 'Repetir anuncio', 'Repetir anúncio', 'Повторить сообщение', '重播通知'],
 'Admin_Close': ['Close', 'Fermer', 'Schließen', 'Cerrar', 'Fechar', 'Закрыть', '关闭'],
 'Relay': ['Relay cabinet', 'Armoire de relais', 'Relaiskasten', 'Armario del repetidor', 'Armário do repetidor', 'Шкаф ретранслятора', '中继柜'],
 'RepairRelay': ['Repair (%1 electronic scrap, %2 s)', 'Réparer (%1 déchets électroniques, %2 s)', 'Reparieren (%1 Elektronikschrott, %2 s)', 'Reparar (%1 chatarra electrónica, %2 s)', 'Reparar (%1 sucata eletrónica, %2 s)', 'Починить (%1 электронного лома, %2 с)', '维修（%1 电子废料，%2 秒）'],
 'RelayOrder': ['Logistics: relay down at %1 / %2. Bring Electronic Scrap and right-click the relay cabinet to repair it. No generator required.', 'Logistique : relais en panne en %1 / %2. Munissez-vous de déchets électroniques, puis clic droit sur l’armoire de relais pour la réparer. Aucun générateur nécessaire.', 'Logistik: Relais bei %1 / %2 ausgefallen. Elektronikschrott mitbringen, Relaiskasten rechtsklicken und reparieren. Kein Generator nötig.', 'Logística: repetidor averiado en %1 / %2. Lleva chatarra electrónica y haz clic derecho en el armario para repararlo. No requiere generador.', 'Logística: repetidor avariado em %1 / %2. Leve sucata eletrónica e clique com o botão direito no armário para o reparar. Não requer gerador.', 'Логистика: ретранслятор в %1 / %2 неисправен. Возьмите электронный лом и выберите ремонт правой кнопкой на шкафу. Генератор не нужен.', '后勤：%1 / %2 的中继故障。携带电子废料，右键点击中继柜维修。无需发电机。'],
 'RelayRestored': ['Logistics: relay repaired. Drop requests available.', 'Logistique : relais réparé. Appels de largage disponibles.', 'Logistik: Relais repariert. Abwürfe wieder verfügbar.', 'Logística: repetidor reparado. Entregas disponibles.', 'Logística: repetidor reparado. Entregas disponíveis.', 'Логистика: ретранслятор починен. Сбросы доступны.', '后勤：中继已修复。可请求空投。'],
 'RelayBypass': ['Logistics: backup link established. Drop requests available.', 'Logistique : liaison de secours établie. Appels disponibles.', 'Logistik: Ersatzverbindung aktiv. Abwürfe verfügbar.', 'Logística: enlace de respaldo activo. Entregas disponibles.', 'Logística: ligação de reserva ativa. Entregas disponíveis.', 'Логистика: резервная связь установлена. Сбросы доступны.', '后勤：备用通信已建立。可请求空投。'],
 'Relay_unavailable': ['Relay unavailable or repair interrupted.', 'Relais indisponible ou réparation interrompue.', 'Relais nicht verfügbar oder Reparatur unterbrochen.', 'Repetidor no disponible o reparación interrumpida.', 'Repetidor indisponível ou reparação interrompida.', 'Ретранслятор недоступен или ремонт прерван.', '中继不可用或维修已中断。'],
 'Relay_components': ['Not enough Electronic Scrap.', 'Pas assez de déchets électroniques.', 'Nicht genug Elektronikschrott.', 'Falta chatarra electrónica.', 'Sucata eletrónica insuficiente.', 'Недостаточно электронного лома.', '电子废料不足。'],
 'Relay_complete': ['Relay repaired. Electrical experience gained.', 'Relais réparé. Expérience en électricité obtenue.', 'Relais repariert. Erfahrung in Elektrik erhalten.', 'Repetidor reparado. Experiencia de electricidad obtenida.', 'Repetidor reparado. Experiência em eletricidade obtida.', 'Ретранслятор починен. Получен опыт электрики.', '中继已修复，获得电工经验。'],
 'Relay_failed': ['Relay down: drop calls suspended. Repair the cabinet announced by Logistics.', 'Relais en panne : appels de largage suspendus. Réparez l’armoire annoncée par la Logistique.', 'Relais ausgefallen: Abwürfe gesperrt. Den angekündigten Relaiskasten reparieren.', 'Repetidor averiado: entregas suspendidas. Repara el armario anunciado.', 'Repetidor avariado: entregas suspensas. Repare o armário anunciado.', 'Ретранслятор неисправен: сбросы приостановлены. Почините указанный шкаф.', '中继故障：空投请求已暂停。请维修后勤通知的中继柜。'],
 'Weekly': ['Weekly requirements', 'Besoins de la semaine', 'Wochenbedarf', 'Necesidades semanales', 'Necessidades semanais', 'Потребности недели', '每周需求'],
 'WeeklyTip': ['Ask which two Fulton categories earn a bonus this week. The daily cap still applies.', 'Demander les deux catégories Fulton bonifiées cette semaine. Le plafond quotidien reste applicable.', 'Die zwei Fulton-Bonuskategorien dieser Woche abfragen. Das Tageslimit bleibt bestehen.', 'Consultar las dos categorías Fulton con bonificación. Se mantiene el límite diario.', 'Consultar as duas categorias Fulton com bónus. O limite diário mantém-se.', 'Узнать две категории Fulton с надбавкой. Дневной предел сохраняется.', '查询本周两类富尔顿加成物资。仍受每日上限限制。'],
 'WeeklyList': ['Logistics weekly priorities: %1 and %2. Bonus %3 percent, within the daily cap.', 'Priorités hebdomadaires : %1 et %2. Bonus de %3 pour cent, dans le plafond quotidien.', 'Wochenprioritäten: %1 und %2. Bonus %3 Prozent innerhalb des Tageslimits.', 'Prioridades semanales: %1 y %2. Bonificación del %3 por ciento, dentro del límite diario.', 'Prioridades semanais: %1 e %2. Bónus de %3 por cento, dentro do limite diário.', 'Приоритеты недели: %1 и %2. Надбавка %3 процентов в пределах дневного лимита.', '每周优先物资：%1 和 %2。加成 %3 百分比，计入每日上限。'],
 'WeeklyChanged': ['Weekly requirements changed. Review the cargo and confirm again; nothing was consumed.', 'Les besoins hebdomadaires ont changé. Vérifiez le chargement et confirmez à nouveau ; rien n’a été consommé.', 'Der Wochenbedarf hat sich geändert. Fracht erneut prüfen und bestätigen; nichts wurde verbraucht.', 'Cambiaron las necesidades semanales. Revisa y confirma de nuevo; no se consumió nada.', 'As necessidades semanais mudaram. Reveja e confirme novamente; nada foi consumido.', 'Потребности недели изменились. Проверьте груз и подтвердите снова; ничего не потрачено.', '每周需求已变更。请重新检查并确认货物，未消耗任何物品。'],
 'Category_identity': ['identity documents', 'pièces d’identité', 'Ausweise', 'documentos de identidad', 'documentos de identificação', 'удостоверения личности', '身份证件'],
 'Category_stashMap': ['annotated maps', 'cartes annotées', 'beschriftete Karten', 'mapas anotados', 'mapas anotados', 'карты с пометками', '标注地图'],
 'Category_gasMask': ['gas masks', 'masques à gaz', 'Gasmasken', 'máscaras antigás', 'máscaras de gás', 'противогазы', '防毒面具'],
 'Category_papers': ['documents', 'documents', 'Dokumente', 'documentos', 'documentos', 'документы', '文件'],
 'Category_gasMaskFilter': ['gas mask filters', 'filtres de masque à gaz', 'Gasmaskenfilter', 'filtros de máscara', 'filtros de máscara', 'фильтры противогазов', '防毒面具滤罐'],
 'Category_scba': ['SCBA equipment', 'appareils respiratoires isolants', 'Atemschutzgeräte', 'equipos respiratorios autónomos', 'equipamento respiratório autónomo', 'изолирующие дыхательные аппараты', '自给式呼吸装备'],
 'HordeReport': ['Report zombie concentration', 'Signaler un rassemblement', 'Zombieansammlung melden', 'Informar concentración zombi', 'Comunicar concentração zumbi', 'Сообщить о скоплении зомби', '报告尸群'],
 'HordeReportTip': ['Report at least 10 living zombies within 30 squares, on the ground floor. The base verifies the area; repeat reports earn nothing.', 'Signaler au moins 10 zombies vivants à 30 cases, au rez-de-chaussée. La base vérifie la zone ; les doublons ne rapportent rien.', 'Mindestens 10 lebende Zombies in 30 Feldern im Erdgeschoss melden. Die Basis prüft; Wiederholungen bringen nichts.', 'Informar de 10 zombis vivos en 30 casillas, a nivel del suelo. La base verifica; los duplicados no dan recompensa.', 'Comunicar 10 zumbis vivos num raio de 30 quadrados, ao nível do solo. A base verifica; duplicados não dão recompensa.', 'Сообщить о 10 живых зомби в радиусе 30 клеток на уровне земли. База проверяет; повторы без награды.', '报告地面层30格内至少10只存活僵尸。基地核实，重复报告无奖励。'],
 'HordeAccepted': ['Logistics: concentration confirmed. Keep clear and monitor mission broadcasts.', 'Logistique : rassemblement confirmé. Restez prudent et écoutez les annonces de mission.', 'Logistik: Ansammlung bestätigt. Vorsichtig bleiben und Aufträge verfolgen.', 'Logística: concentración confirmada. Mantente alerta a las misiones.', 'Logística: concentração confirmada. Aguarde os anúncios de missão.', 'Логистика: скопление подтверждено. Следите за заданиями.', '后勤：已确认尸群。保持警惕并收听任务通知。'],
 'HordeDuplicate': ['This area was already reported recently.', 'Cette zone a déjà été signalée récemment.', 'Dieses Gebiet wurde kürzlich bereits gemeldet.', 'Esta zona ya se informó recientemente.', 'Esta área já foi comunicada recentemente.', 'Об этом районе уже недавно сообщали.', '近期已有人报告此区域。'],
 'HordeInsufficient': ['No concentration confirmed. At least 10 living zombies within 30 squares on the ground floor are required.', 'Rassemblement non confirmé : il faut 10 zombies vivants à 30 cases, au rez-de-chaussée.', 'Keine Ansammlung bestätigt. Erforderlich: 10 lebende Zombies in 30 Feldern im Erdgeschoss.', 'Sin concentración confirmada: se requieren 10 zombis vivos en 30 casillas a nivel del suelo.', 'Concentração não confirmada: são necessários 10 zumbis vivos em 30 quadrados ao nível do solo.', 'Скопление не подтверждено: нужно 10 живых зомби в 30 клетках на уровне земли.', '未确认尸群：需地面层30格内至少10只存活僵尸。'],
 'Receipt': ['Confirm supply receipt', 'Confirmer la réception', 'Empfang bestätigen', 'Confirmar recepción', 'Confirmar receção', 'Подтвердить получение', '确认收到补给'],
 'ReceiptTip': ['Confirm your most recently opened supply drop, within 72 game hours. Each drop can be acknowledged once.', 'Confirmer votre dernier largage ouvert, sous 72 heures de jeu. Une seule confirmation par largage.', 'Den zuletzt geöffneten eigenen Abwurf innerhalb von 72 Spielstunden bestätigen. Einmal pro Abwurf.', 'Confirmar tu última entrega abierta en 72 horas de juego. Una vez por entrega.', 'Confirmar a última entrega aberta em 72 horas de jogo. Uma vez por entrega.', 'Подтвердить последний открытый сброс в течение 72 игровых часов. Один раз на сброс.', '在72游戏小时内确认最近打开的己方空投。每次空投仅一次。'],
 'ReceiptAccepted': ['Logistics: receipt acknowledged. Thank you.', 'Logistique : réception confirmée. Merci.', 'Logistik: Empfang bestätigt. Danke.', 'Logística: recepción confirmada. Gracias.', 'Logística: receção confirmada. Obrigado.', 'Логистика: получение подтверждено. Спасибо.', '后勤：已确认收到。谢谢。'],
 'ReceiptNone': ['No supply drop awaiting your acknowledgement.', 'Aucun largage en attente de votre confirmation.', 'Kein Abwurf wartet auf Ihre Bestätigung.', 'No hay entregas pendientes de tu confirmación.', 'Nenhuma entrega aguarda a sua confirmação.', 'Нет сбросов, ожидающих подтверждения.', '没有等待您确认的补给空投。'],
 'CitationTitle': ['Command citation', 'Citation du commandement', 'Auszeichnung des Kommandos', 'Mención del mando', 'Louvor do comando', 'Благодарность командования', '指挥部嘉奖'],
 'CitationText': ['COMMAND CITATION\n\n%1\n\nFor service to the logistics network.\nTrust level %2 reached for the first time.\n\nCommand thanks you.', 'CITATION DU COMMANDEMENT\n\n%1\n\nPour services rendus au réseau logistique.\nPalier de confiance %2 atteint pour la première fois.\n\nLe commandement vous remercie.', 'AUSZEICHNUNG DES KOMMANDOS\n\n%1\n\nFür den Dienst am Logistiknetz.\nVertrauensstufe %2 erstmals erreicht.\n\nDas Kommando dankt Ihnen.', 'MENCIÓN DEL MANDO\n\n%1\n\nPor su servicio a la red logística.\nNivel de confianza %2 alcanzado por primera vez.\n\nEl mando le da las gracias.', 'LOUVOR DO COMANDO\n\n%1\n\nPelos serviços à rede logística.\nNível de confiança %2 atingido pela primeira vez.\n\nO comando agradece.', 'БЛАГОДАРНОСТЬ КОМАНДОВАНИЯ\n\n%1\n\nЗа службу логистической сети.\nУровень доверия %2 достигнут впервые.\n\nКомандование благодарит вас.', '指挥部嘉奖\n\n%1\n\n感谢您为后勤网络提供的服务。\n首次达到信任等级 %2。\n\n指挥部向您致谢。'],
 'HonoraryTag': ['Honorary service tag - %1', 'Plaque de service honorifique - %1', 'Ehrendienstmarke - %1', 'Placa de servicio honorífica - %1', 'Placa de serviço honorífica - %1', 'Почётный служебный жетон - %1', '荣誉服役铭牌 - %1'],
}
rows.update({
 'Mission_Relay': ['Restore a relay', 'Remettre un relais en service', 'Relais wiederherstellen',
    'Restaurar un repetidor', 'Restaurar um retransmissor', 'Восстановить ретранслятор', '修复中继站'],
 'PostRelayInstructions': [
    'Reach the announced relay cabinet with Electronics Scrap. Right-click the cabinet and choose Repair. Electricity reduces the cost from 20 to 2 scrap and the duration from 15 to 3 seconds. Grants Electricity XP and trust. No generator required. Repair the cabinet on site, not from this console.',
    'Rejoignez l’armoire de relais annoncée avec des déchets électroniques. Clic droit sur l’armoire, puis Réparer. L’Électricité réduit le coût de 20 à 2 déchets et la durée de 15 à 3 secondes. Gain d’XP en Électricité et de confiance. Aucun générateur requis. La réparation se fait sur place, pas depuis cette console.',
    'Mit Elektronikschrott zum gemeldeten Relaisschrank gehen. Rechtsklick und Reparieren. Elektrik senkt den Bedarf von 20 auf 2 und die Dauer von 15 auf 3 Sekunden. Gibt Elektrik-XP und Vertrauen. Kein Generator nötig. Reparatur vor Ort, nicht an dieser Konsole.',
    'Ve al armario anunciado con chatarra electrónica. Clic derecho y Reparar. Electricidad reduce el coste de 20 a 2 y la duración de 15 a 3 segundos. Otorga XP y confianza. Sin generador. Repara en el lugar, no desde esta consola.',
    'Vá ao armário anunciado com sucata eletrónica. Clique direito e Reparar. Eletricidade reduz o custo de 20 para 2 e o tempo de 15 para 3 segundos. Dá XP e confiança. Sem gerador. Repare no local, não nesta consola.',
    'Доберитесь до указанного шкафа с электронным ломом. ПКМ и Ремонт. Электрика снижает расход с 20 до 2 и время с 15 до 3 секунд. Даёт опыт и доверие. Генератор не нужен. Ремонтировать нужно на месте, не с этой консоли.',
    '携带电子废料前往公告指定的中继柜。右键选择维修。电工技能将消耗从20降至2，时间从15秒降至3秒，并获得电工经验和信任。无需发电机，必须在现场维修，不能通过此控制台远程维修。'],
 'RecorderTooltipProvider': ['Flight recorder transmission status', 'État de transmission des enregistreurs',
    'Flugschreiber-Übertragungsstatus', 'Estado de transmisión de grabadoras', 'Estado de transmissão dos gravadores',
    'Статус передачи самописца', '飞行记录器传输状态'],
 'RecorderTransmitted': ['Data already transmitted to the base', 'Données déjà transmises à la base',
    'Daten bereits an die Basis übertragen', 'Datos ya transmitidos a la base', 'Dados já transmitidos à base',
    'Данные уже переданы на базу', '数据已传输至基地'],
 'RecorderDismantleHint': ['You can dismantle this recorder. It does not need transmitting again.',
    'Vous pouvez démonter cet enregistreur. Aucun nouvel envoi n’est nécessaire.',
    'Dieser Flugschreiber kann zerlegt werden. Keine erneute Übertragung nötig.',
    'Puedes desmontar esta grabadora. No necesita otra transmisión.',
    'Pode desmontar este gravador. Não precisa de nova transmissão.',
    'Этот самописец можно разобрать. Повторная передача не нужна.',
    '可拆解此记录器，无需再次传输。'],
})
update(base, 'IG_UI', rows, 'IGUI_MilitaryDrop_')
options = {
 'WeeklyBonusPercent': ['Weekly Fulton bonus (percent)', 'Bonus Fulton hebdomadaire (pour cent)', 'Fulton-Wochenbonus (Prozent)', 'Bonificación semanal Fulton (por ciento)', 'Bónus semanal Fulton (por cento)', 'Недельная надбавка Fulton (проценты)', '富尔顿每周加成（百分比）'],
 'RotorNoisePercent': ['Rotor attraction noise (percent)', 'Bruit attractif des rotors (pour cent)', 'Rotor-Lockgeräusch (Prozent)', 'Ruido de atracción del rotor (por ciento)', 'Ruído de atração do rotor (por cento)', 'Шум ротора для привлечения (проценты)', '旋翼吸引噪声（百分比）'],
 'LandingNoisePercent': ['Drop attraction noise (percent)', 'Bruit attractif du largage (pour cent)', 'Abwurf-Lockgeräusch (Prozent)', 'Ruido de atracción de la entrega (por ciento)', 'Ruído de atração da entrega (por cento)', 'Шум сброса для привлечения (проценты)', '空投吸引噪声（百分比）'],
 'RelayEnabled': ['Relay repair missions', 'Missions de réparation des relais', 'Relais-Reparaturaufträge', 'Misiones de reparación de repetidores', 'Missões de reparação de repetidores', 'Задания по ремонту ретрансляторов', '中继维修任务'],
 'RelayRearmDays': ['Minimum days between relay failures', 'Jours minimum entre deux pannes', 'Mindesttage zwischen Relaisausfällen', 'Días mínimos entre averías', 'Dias mínimos entre avarias', 'Минимум дней между поломками', '中继故障最短间隔天数'],
 'HordeReportGain': ['Trust for a verified concentration report', 'Confiance pour un rassemblement vérifié', 'Vertrauen für bestätigte Ansammlung', 'Confianza por concentración verificada', 'Confiança por concentração verificada', 'Доверие за подтверждённое скопление', '核实尸群报告的信任奖励'],
 'ReceiptGain': ['Trust for supply receipt acknowledgement', 'Confiance pour confirmation de réception', 'Vertrauen für Empfangsbestätigung', 'Confianza por confirmar recepción', 'Confiança por confirmar receção', 'Доверие за подтверждение получения', '确认收到补给的信任奖励'],
}
update(base, 'Sandbox', options, 'Sandbox_MilitaryDrop_')
tips = {
 'WeeklyBonusPercent': ['Bonus for two categories, rotated each Monday. Included in the daily trust cap. 0 disables the bonus.', 'Bonus sur deux catégories, renouvelées chaque lundi. Inclus dans le plafond quotidien. 0 désactive le bonus.', 'Bonus für zwei Kategorien, jeden Montag neu. Zählt zum Tageslimit. 0 deaktiviert den Bonus.', 'Bonificación para dos categorías cada lunes. Cuenta para el límite diario. 0 la desactiva.', 'Bónus para duas categorias a cada segunda-feira. Conta para o limite diário. 0 desativa.', 'Надбавка для двух категорий с понедельника. Входит в дневной лимит. 0 отключает.', '每周一轮换两类加成。计入每日信任上限。0禁用加成。'],
 'RotorNoisePercent': ['100: normal attraction, 0: no rotor attraction. The configured landing horde still spawns.', '100 : attraction normale, 0 : aucune attraction par les rotors. La horde prévue au largage apparaît toujours.', '100: normale Anlockung, 0: keine Rotoranlockung. Die konfigurierte Horde erscheint weiterhin.', '100: atracción normal, 0: sin atracción del rotor. La horda configurada sigue apareciendo.', '100: atração normal, 0: sem atração do rotor. A horda configurada continua a aparecer.', '100: обычное привлечение, 0: ротор не привлекает. Настроенная орда всё равно появляется.', '100为正常吸引，0关闭旋翼吸引。仍生成配置的空投尸群。'],
 'LandingNoisePercent': ['100: normal attraction at actual delivery, 0: no landing attraction. The configured horde still spawns.', '100 : attraction normale à la livraison effective, 0 : aucune attraction à l’arrivée. La horde prévue apparaît toujours.', '100: normale Anlockung bei Lieferung, 0: keine. Die konfigurierte Horde erscheint weiterhin.', '100: atracción normal al entregar, 0: ninguna. La horda configurada sigue apareciendo.', '100: atração normal na entrega, 0: nenhuma. A horda configurada continua a aparecer.', '100: обычное привлечение при доставке, 0: нет. Настроенная орда всё равно появляется.', '100为实际交付时的正常吸引，0关闭。仍生成配置的尸群。'],
 'RelayEnabled': ['A storm or power-grid outage can damage a relay. Repairs use Electronic Scrap only. Backup link after 72 game hours.', 'Un orage ou la coupure du réseau électrique peut endommager un relais. Réparation avec déchets électroniques uniquement. Secours après 72 heures de jeu.', 'Sturm oder Stromausfall kann ein Relais beschädigen. Reparatur nur mit Elektronikschrott. Ersatzverbindung nach 72 Spielstunden.', 'Tormentas o apagones pueden averiar un repetidor. Solo requiere chatarra electrónica. Respaldo tras 72 horas de juego.', 'Tempestades ou apagões podem avariar um repetidor. Só requer sucata eletrónica. Reserva após 72 horas de jogo.', 'Гроза или отключение сети могут сломать ретранслятор. Нужен только электронный лом. Резерв через 72 игровых часа.', '雷暴或停电可导致中继故障。仅需电子废料维修。72游戏小时后启用备用通信。'],
 'RelayRearmDays': ['Minimum game days after repair or backup before another relay failure.', 'Jours de jeu minimum après réparation ou secours avant une nouvelle panne.', 'Mindestspieltage nach Reparatur oder Ersatzverbindung bis zum nächsten Ausfall.', 'Días de juego mínimos tras reparación o respaldo antes de otra avería.', 'Dias de jogo mínimos após reparação ou reserva até nova avaria.', 'Минимум игровых дней после ремонта или резерва до новой поломки.', '维修或备用通信后再次故障的最短游戏天数。'],
 'HordeReportGain': ['Daily capped trust for a verified concentration. 0 disables reports. Same area: one report per 24 game hours.', 'Confiance plafonnée pour un rassemblement vérifié. 0 désactive les signalements. Même zone : une fois par 24 heures de jeu.', 'Täglich begrenztes Vertrauen für bestätigte Ansammlungen. 0 deaktiviert. Gleiches Gebiet: einmal pro 24 Spielstunden.', 'Confianza con límite diario. 0 desactiva. Misma zona: una vez por 24 horas de juego.', 'Confiança com limite diário. 0 desativa. Mesma área: uma vez por 24 horas de jogo.', 'Доверие с дневным лимитом. 0 отключает. Тот же район: раз в 24 игровых часа.', '核实尸群的信任奖励受每日上限限制。0禁用。同一区域每24游戏小时一次。'],
 'ReceiptGain': ['Daily capped trust for one acknowledgement per personal recovered drop. 0 disables acknowledgements.', 'Confiance plafonnée pour une confirmation par largage personnel récupéré. 0 désactive les confirmations.', 'Täglich begrenztes Vertrauen für eine Bestätigung pro geborgenem eigenem Abwurf. 0 deaktiviert.', 'Confianza limitada por una confirmación por entrega propia recuperada. 0 desactiva.', 'Confiança limitada por uma confirmação por entrega própria recuperada. 0 desativa.', 'Доверие с лимитом за одно подтверждение полученного личного сброса. 0 отключает.', '每次收回的个人空投可确认一次，奖励受每日上限限制。0禁用。'],
}
update(base, 'Sandbox', {key + '_tooltip': value for key, value in tips.items()}, 'Sandbox_MilitaryDrop_')
update(base, 'ItemName', {'MilitaryDrop.CommandCitation': rows['CitationTitle']}, 'ItemName_')

jammer = ROOT / 'batman_MilitaryDropJammer/42.21/media/lua/shared/Translate'
# Explicit translations for the optional UI, with PTBR sharing the PT wording.
jamrows = {
 'Title': ['RJ-93 Radio Jammer', 'Brouilleur radio RJ-93', 'RJ-93 Funkstörsender', 'Inhibidor de radio RJ-93', 'Bloqueador de rádio RJ-93', 'Радиоглушитель RJ-93', 'RJ-93 无线电干扰器'],
 'Control': ['Control jammer', 'Contrôler le brouilleur', 'Störsender bedienen', 'Controlar inhibidor', 'Controlar bloqueador', 'Управлять глушителем', '控制干扰器'],
 'TurnOn': ['Turn on', 'Allumer', 'Einschalten', 'Encender', 'Ligar', 'Включить', '开启'],
 'TurnOff': ['Turn off', 'Éteindre', 'Ausschalten', 'Apagar', 'Desligar', 'Выключить', '关闭'],
 'Insert': ['Insert battery', 'Insérer une pile', 'Batterie einsetzen', 'Insertar pila', 'Inserir pilha', 'Вставить батарейку', '装入电池'],
 'Remove': ['Remove battery', 'Retirer la pile', 'Batterie entnehmen', 'Retirar pila', 'Retirar pilha', 'Извлечь батарейку', '取出电池'],
 'Status': ['Status', 'État', 'Status', 'Estado', 'Estado', 'Состояние', '状态'],
 'Radius': ['Range (squares)', 'Portée (cases)', 'Reichweite (Felder)', 'Alcance (casillas)', 'Alcance (quadrados)', 'Радиус (клетки)', '范围（格）'],
 'Loading': ['Loading...', 'Chargement...', 'Laden...', 'Cargando...', 'A carregar...', 'Загрузка...', '载入中……'],
 'NoBattery': ['No battery', 'Sans pile', 'Keine Batterie', 'Sin pila', 'Sem pilha', 'Нет батарейки', '无电池'],
 'Empty': ['Battery depleted', 'Pile épuisée', 'Batterie leer', 'Pila agotada', 'Pilha descarregada', 'Батарейка разряжена', '电池耗尽'],
 'On': ['On', 'Actif', 'Ein', 'Activo', 'Ativo', 'Включён', '开启'],
 'Off': ['Off', 'Éteint', 'Aus', 'Apagado', 'Desligado', 'Выключен', '关闭'],
 'Occupied': ['Battery slot occupied', 'Logement de pile occupé', 'Batteriefach belegt', 'Compartimento ocupado', 'Compartimento ocupado', 'Отсек занят', '电池槽已占用'],
 'ChooseBattery': ['Choose a battery from your inventory', 'Choisir une pile dans votre inventaire', 'Batterie aus dem Inventar wählen', 'Elige una pila del inventario', 'Escolha uma pilha do inventário', 'Выберите батарейку из инвентаря', '选择物品栏中的电池'],
 'Hint1': ['Blocks logistics calls, including your own.', 'Bloque les appels, y compris les vôtres.', 'Blockiert auch Ihre eigenen Anrufe.', 'Bloquea llamadas, incluidas las tuyas.', 'Bloqueia chamadas, incluindo as suas.', 'Блокирует и ваши собственные вызовы.', '也会阻止您自己的后勤呼叫。'],
 'Hint2': ['Public broadcasts are still received.', 'Les annonces publiques restent reçues.', 'Öffentliche Meldungen bleiben hörbar.', 'Los anuncios públicos siguen llegando.', 'Os anúncios públicos continuam audíveis.', 'Общие сообщения по-прежнему слышны.', '仍可接收公共广播。'],
 'Blocked': ['Link unavailable: radio jamming detected. Move away or disable the source. Public broadcasts remain audible.', 'Liaison indisponible : brouillage radio détecté. Éloignez-vous ou désactivez la source. Les annonces publiques restent audibles.', 'Verbindung gestört: Funkstörung erkannt. Entfernen Sie sich oder schalten Sie die Quelle aus. Öffentliche Meldungen bleiben hörbar.', 'Enlace no disponible: interferencias detectadas. Aléjate o desactiva la fuente. Los anuncios públicos siguen audibles.', 'Ligação indisponível: interferência detetada. Afaste-se ou desative a fonte. Os anúncios públicos continuam audíveis.', 'Связь недоступна: обнаружено радиоподавление. Отойдите или отключите источник. Общие сообщения слышны.', '通信不可用：检测到无线电干扰。请远离或关闭干扰源。仍可收听公共广播。'],
 'Restored': ['Jamming ended: link available.', 'Brouillage terminé : liaison disponible.', 'Störung beendet: Verbindung verfügbar.', 'Interferencias terminadas: enlace disponible.', 'Interferência terminada: ligação disponível.', 'Подавление закончилось: связь доступна.', '干扰已结束，通信恢复。'],
 'LinkJammed': ['Link jammed', 'Liaison brouillée', 'Verbindung gestört', 'Enlace interferido', 'Ligação bloqueada', 'Связь подавлена', '通信受干扰'],
 'Error_unavailable': ['Device unavailable or out of reach.', 'Appareil indisponible ou trop éloigné.', 'Gerät nicht verfügbar oder außer Reichweite.', 'Dispositivo no disponible o fuera de alcance.', 'Dispositivo indisponível ou fora de alcance.', 'Устройство недоступно или далеко.', '设备不可用或距离过远。'],
 'Error_ground': ['Place the jammer on the ground.', 'Posez le brouilleur au sol.', 'Störsender auf den Boden stellen.', 'Coloca el inhibidor en el suelo.', 'Coloque o bloqueador no chão.', 'Поставьте глушитель на землю.', '请将干扰器放在地上。'],
 'Error_limit': ['Device limit reached.', 'Limite d’appareils atteinte.', 'Gerätelimit erreicht.', 'Límite de dispositivos alcanzado.', 'Limite de dispositivos atingido.', 'Достигнут предел устройств.', '设备数量已达上限。'],
 'Error_disabled': ['Jammers are disabled in server options.', 'Brouilleurs désactivés dans les options serveur.', 'Störsender sind auf dem Server deaktiviert.', 'Inhibidores desactivados en el servidor.', 'Bloqueadores desativados no servidor.', 'Глушители отключены в настройках сервера.', '服务器已禁用干扰器。'],
 'Error_empty': ['A charged battery is required.', 'Une pile chargée est nécessaire.', 'Eine geladene Batterie ist erforderlich.', 'Se requiere una pila cargada.', 'É necessária uma pilha carregada.', 'Нужна заряженная батарейка.', '需要有电的电池。'],
 'Error_occupied': ['Remove the installed battery first.', 'Retirez d’abord la pile installée.', 'Zuerst die eingesetzte Batterie entnehmen.', 'Retira primero la pila instalada.', 'Retire primeiro a pilha instalada.', 'Сначала извлеките установленную батарейку.', '请先取出已安装的电池。'],
 'Error_noBattery': ['No compatible battery available.', 'Aucune pile compatible disponible.', 'Keine passende Batterie verfügbar.', 'No hay pila compatible disponible.', 'Nenhuma pilha compatível disponível.', 'Нет подходящей батарейки.', '没有可用的兼容电池。'],
 'Error_full': ['Not enough inventory capacity.', 'Capacité d’inventaire insuffisante.', 'Nicht genug Platz im Inventar.', 'No hay espacio en el inventario.', 'Sem espaço no inventário.', 'Недостаточно места в инвентаре.', '物品栏容量不足。'],
}
update(jammer, 'IG_UI', jamrows, 'IGUI_MDJ_')
update(jammer, 'ItemName', {'MilitaryDropJammer.RJ93': jamrows['Title']}, 'ItemName_')
update(jammer, 'Recipes', {'MakeRJ93': ['Make radio jammer', 'Fabriquer un brouilleur RJ-93', 'Funkstörsender bauen', 'Fabricar inhibidor de radio', 'Fabricar bloqueador de rádio', 'Собрать радиоглушитель', '制作无线电干扰器']}, '')
update(jammer, 'Sandbox', {
 '': jamrows['Title'], 'Enabled': ['Enable jammers', 'Brouilleurs actifs', 'Störsender aktivieren', 'Activar inhibidores', 'Ativar bloqueadores', 'Включить глушители', '启用干扰器'],
 'Radius': jamrows['Radius'],
 'BatteryHours': ['Battery lifetime (game hours)', 'Autonomie de la pile (heures de jeu)', 'Batterielaufzeit (Spielstunden)', 'Autonomía de la pila (horas de juego)', 'Autonomia da pilha (horas de jogo)', 'Время работы (игровые часы)', '电池续航（游戏小时）'],
}, 'Sandbox_MilitaryDropJammer_')
for path in jammer.glob('*/Sandbox.json'):
    values = json.loads(path.read_text(encoding='utf-8'))
    values['Sandbox_MilitaryDropJammer'] = values.pop('Sandbox_MilitaryDropJammer_')
    path.write_text(json.dumps(values, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')
path = jammer / 'FR/Sandbox.json'
values = json.loads(path.read_text(encoding='utf-8'))
values['Sandbox_MilitaryDropJammer_Radius'] = 'Portée (cases)'
path.write_text(json.dumps(values, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')
path = jammer / 'FR/Recipes.json'
path.write_text(json.dumps({'MakeRJ93': 'Fabriquer un brouilleur RJ-93'}, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')
