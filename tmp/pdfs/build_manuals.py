from pathlib import Path
import hashlib, json, re
from html import escape
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph, Table, TableStyle, Spacer, KeepTogether
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/pdf'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'release/Albert-V2.ahk'
DIGEST = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
for name, file in [('A','arial.ttf'),('AB','arialbd.ttf'),('AI','ariali.ttf')]:
    pdfmetrics.registerFont(TTFont(name, 'C:/Windows/Fonts/'+file))
pdfmetrics.registerFontFamily('A', normal='A', bold='AB', italic='AI', boldItalic='AB')
W,H = 595.276,841.89
NAVY=colors.HexColor('#142B46'); TEAL=colors.HexColor('#007F80')
INK=colors.HexColor('#23384A'); MUTED=colors.HexColor('#536675')
LIGHT=colors.HexColor('#EDF5F6'); LINE=colors.HexColor('#D9E3E8')
styles={
 'body':ParagraphStyle('body',fontName='A',fontSize=11,leading=16,textColor=INK,spaceAfter=9),
 'h':ParagraphStyle('h',fontName='AB',fontSize=12,leading=16,textColor=NAVY,spaceBefore=11,spaceAfter=7),
 'title':ParagraphStyle('title',fontName='AB',fontSize=23,leading=28,textColor=NAVY,spaceAfter=13),
 'deck':ParagraphStyle('deck',fontName='A',fontSize=12,leading=17,textColor=MUTED,spaceAfter=17),
 'cell':ParagraphStyle('cell',fontName='A',fontSize=10,leading=14,textColor=INK),
 'th':ParagraphStyle('th',fontName='AB',fontSize=10,leading=14,textColor=colors.white),
 'note':ParagraphStyle('note',fontName='A',fontSize=10.5,leading=15,textColor=INK),
}
def clean(s):
    return s.replace('—','-').replace('–','-').replace('\u2011','-')
def para(s, style='body'):
    return Paragraph(escape(clean(s)).replace('\n','<br/>'),styles[style])
def S(title, text): return ('section', title, text)
def N(text): return ('note',text)
def T(headers,rows): return ('table',headers,rows)
PAGES=[]
def add(ru,uz,br,bu,tag='ALBERT / GUIDE'):
    PAGES.append({'ru':ru,'uz':uz,'br':br,'bu':bu,'tag':tag})

add('Рабочее место и режимы','Ish joyi va rejimlar',[
 S('Что делает Albert','Albert связывает CRM, таблицы, MicroSIP и Telegram горячими клавишами. Он имитирует ввод, переключает окна и использует буфер обмена. Перед действием проверьте режим и активное поле: скрипт не понимает содержимое любого открытого окна.'),
 T(['Режим','Назначение'],[['BITRIX','Номер из CRM -> поиск Telegram -> звонок.'],['MICROSIP','Обзвон таблицы; статус через два столбца справа.'],['SVERKA','Сверка; статус в соседнем столбце справа.'],['TELEGRAM','Номера из таблицы в текущее поле Telegram.'],['SAP','Звонок по выделению и ввод готовых текстов.'],['NORMAL','Обычный ввод для части клавиш.']]),
 S('Где смотреть состояние','После обычного запуска выбран BITRIX. Постоянный индикатор показывает режим у панели задач. Рядом с MicroSIP отображаются текущий номер, счётчик попыток и продажи за день. При сворачивании MicroSIP его виджеты скрываются.'),
 N('Рабочие столы: 1 - без запуска программ; 2 - Telegram, MicroSIP, Bitrix; 3 - калькулятор и склад; 4 - необязательные таблицы. ZIK в этом релизе отсутствует.')
],[
 S('Albert nima qiladi','Albert CRM, jadvallar, MicroSIP va Telegram bilan ishlashni tezkor tugmalar orqali birlashtiradi. U tugma bosishlarini yuboradi, oynalarni almashtiradi va almashuv buferidan foydalanadi. Har bir amaldan oldin rejim va faol maydonni tekshiring.'),
 T(['Rejim','Vazifasi'],[['BITRIX','CRM raqami -> Telegram qidiruvi -> qo‘ng‘iroq.'],['MICROSIP','Jadval bo‘yicha qo‘ng‘iroq; holat ikki ustun o‘ngda.'],['SVERKA','Tekshiruv; holat yonidagi o‘ng ustunda.'],['TELEGRAM','Jadvaldagi raqamlarni Telegram maydoniga olish.'],['SAP','Belgilangan raqamga qo‘ng‘iroq va tayyor matnlar.'],['NORMAL','Ayrim tugmalarning odatiy ishlashi.']]),
 S('Holatni qayerda ko‘rish mumkin','Oddiy ishga tushirishda BITRIX tanlanadi. Vazifalar paneli yonidagi doimiy indikator rejimni ko‘rsatadi. MicroSIP yonida joriy raqam, urinishlar soni va bugungi savdolar chiqadi. MicroSIP kichraytirilganda uning vidjetlari yashiriladi.'),
 N('Ish stollari: 1 - dastur ochilmaydi; 2 - Telegram, MicroSIP, Bitrix; 3 - kalkulyator va ombor; 4 - ixtiyoriy jadvallar. Ushbu relizda ZIK yo‘q.')
], '01 / WORKSPACE')

add('F11, F12, End и Escape','F11, F12, End va Escape',[
 T(['Клавиша','Фактическое действие'],[['F11','BITRIX <-> SVERKA. Из другого режима сначала BITRIX.'],['F12','SAP -> TELEGRAM -> MICROSIP -> SAP. Из другого режима сначала SAP.'],['End','Переводит в NORMAL; само нажатие End также получает активная программа.'],['Escape','Остаётся Escape, но может закрыть неподтверждённый звонок в статистике как NO_ANSWER.']]),
 S('Перед рабочей операцией','Нажмите F11 или F12 до нужной надписи в индикаторе. При смене режима номера и окна автоматически не подготавливаются. Например, после перехода в SAP сначала выделите новый номер и используйте F2.'),
 S('Что означает NORMAL','F1-F4, F6-F9, Insert, Home, PrintScreen и Volume_Mute возвращаются к обычному действию. Тильда тоже вводится как обычная клавиша. Однако F10, F11, F12 и некоторые системные макросы продолжают работать.'),
 N('NORMAL - не полное выключение Albert. Volume_Up/Down, Browser_Home, Launch_Media, PgDn и ScrollLock продолжают выполнять макросы. Для полного отключения завершите Albert через значок AutoHotkey в трее.'),
 S('Осторожно с Escape','Escape в любом приложении может изменить учёт текущего звонка. Если вы лишь закрыли поиск Telegram, это не доказывает недозвон. Во время подтверждения F9 эта статистическая реакция временно отключена.')
],[
 T(['Tugma','Haqiqiy amal'],[['F11','BITRIX <-> SVERKA. Boshqa rejimdan avval BITRIX.'],['F12','SAP -> TELEGRAM -> MICROSIP -> SAP. Boshqa rejimdan avval SAP.'],['End','NORMAL rejimiga o‘tadi; faol dastur ham End bosilishini oladi.'],['Escape','Oddiy Escape bo‘lib qoladi, lekin tasdiqlanmagan qo‘ng‘iroqni statistikada NO_ANSWER deb yakunlashi mumkin.']]),
 S('Ish amalidan oldin','Indikatorda kerakli rejim chiqquncha F11 yoki F12 ni bosing. Rejim almashtirilishi raqam va oynalarni avtomatik tayyorlamaydi. Masalan, SAP ga o‘tgach, yangi raqamni belgilang va F2 dan foydalaning.'),
 S('NORMAL nimani anglatadi','F1-F4, F6-F9, Insert, Home, PrintScreen va Volume_Mute odatiy vazifasiga qaytadi. Tilda ham oddiy tugma sifatida ishlaydi. Lekin F10, F11, F12 va ayrim tizim makroslari faol qoladi.'),
 N('NORMAL Albertni to‘liq o‘chirmaydi. Volume_Up/Down, Browser_Home, Launch_Media, PgDn va ScrollLock makroslari ishlashda davom etadi. To‘liq o‘chirish uchun treydagi AutoHotkey belgisi orqali Albertdan chiqing.'),
 S('Escape bilan ehtiyot bo‘ling','Istalgan dasturda Escape bosilishi joriy qo‘ng‘iroq hisobiga ta’sir qilishi mumkin. Telegram qidiruvini yopish mijoz javob bermaganini bildirmaydi. F9 tasdiqlash oynasi vaqtida ushbu statistik reaksiya vaqtincha o‘chiriladi.')
], '02 / MODE KEYS')

add('F1 - повтор или текущий номер','F1 - takroriy qo‘ng‘iroq yoki joriy raqam',[
 T(['Режим','Что происходит'],[['MICROSIP / BITRIX / SVERKA','Активируется MicroSIP, затем Win+1 и Enter, Up, Enter. Счётчик попыток увеличивается.'],['SAP','Набирается сохранённый номер из виджета. Буфер обмена сохраняется и восстанавливается.'],['TELEGRAM','Поле очищается; через Alt+Tab берётся номер из текущей ячейки таблицы и вставляется с 998.'],['NORMAL','Обычная F1 активной программы.']]),
 S('Как повторить звонок в SAP','1. Сначала получите номер через F2 в SAP.\n2. Убедитесь, что нужный номер виден у MicroSIP.\n3. Нажмите F1 для повторного набора. Без сохранённого номера появится подсказка сначала использовать F2.'),
 S('Как взять номер в TELEGRAM','Держите таблицу предыдущим окном Alt+Tab, а нужную ячейку - активной. F1 начинает чтение с этой ячейки, а не обязательно со следующей строки. F3 в TELEGRAM отличается тем, что сначала переводит таблицу на строку вниз.'),
 N('В MICROSIP, BITRIX и SVERKA повтор зависит от состояния интерфейса MicroSIP: используется последовательность Enter/Up/Enter. Не нажимайте F1 многократно вслепую и проверьте фактически набранный номер.')
],[
 T(['Rejim','Nima sodir bo‘ladi'],[['MICROSIP / BITRIX / SVERKA','MicroSIP faollashadi, so‘ng Win+1 va Enter, Up, Enter yuboriladi. Urinish hisoblagichi oshadi.'],['SAP','Vidjetdagi saqlangan raqam teriladi. Almashuv buferi saqlanib, keyin tiklanadi.'],['TELEGRAM','Maydon tozalanadi; Alt+Tab orqali jadvalning joriy katagidan raqam olinib, 998 bilan qo‘yiladi.'],['NORMAL','Faol dasturning oddiy F1 tugmasi.']]),
 S('SAP da qayta qo‘ng‘iroq qilish','1. Avval SAP rejimida F2 orqali raqamni oling.\n2. MicroSIP yonida kerakli raqam ko‘rinayotganini tekshiring.\n3. Qayta terish uchun F1 ni bosing. Raqam saqlanmagan bo‘lsa, avval F2 dan foydalanish haqida xabar chiqadi.'),
 S('TELEGRAM da raqam olish','Jadval Alt+Tab dagi oldingi oyna bo‘lsin, kerakli katak faol tursin. F1 aynan shu katakdan o‘qishni boshlaydi; u har doim keyingi qatorga o‘tmaydi. TELEGRAM dagi F3 esa avval jadvalda bir qator pastga tushadi.'),
 N('MICROSIP, BITRIX va SVERKA da takroriy qo‘ng‘iroq MicroSIP oynasi holatiga bog‘liq: Enter/Up/Enter ketma-ketligi ishlatiladi. F1 ni ko‘r-ko‘rona takror bosmang; amalda terilgan raqamni tekshiring.')
], '03 / F1')

add('F2 - номер, поиск или boradi','F2 - raqam, qidiruv yoki boradi',[
 T(['Режим','Действие F2'],[['MICROSIP','Записать настраиваемый статус F2, обычно boradi; взять следующий номер и позвонить.'],['BITRIX','Скопировать выделенный номер, добавить 998 и вставить в поиск Telegram. Сам звонок не начинается.'],['SVERKA','Записать статус Сверка F2 справа от номера, перейти к следующему и позвонить.'],['TELEGRAM','Home, затем Delete три раза: удаляются первые три символа текущего поля.'],['SAP','Скопировать выделенный номер и позвонить через MicroSIP без 998.']]),
 S('Подготовка для SAP и BITRIX','Выделяйте только телефон, например двойным щелчком, а не строку с дополнительными числами. Проверяется количество цифр: от 9 до 12. Пробелы и знаки удаляются. Для 10-11 цифр берутся последние 9; это очистка формата, а не проверка владельца номера.'),
 S('Геометрия таблицы','MICROSIP пишет статус через два столбца вправо. SVERKA использует один столбец вправо. Переход SVERKA после Enter предполагает стандартное движение выделения вниз. Если ваша таблица настроена иначе, следующий номер может быть выбран неверно.'),
 N('В TELEGRAM F2 не проверяет, что первые три символа действительно 998. Нажимайте только в нужном поле. В NORMAL клавиша сохраняет обычное действие.')
],[
 T(['Rejim','F2 amali'],[['MICROSIP','F2 holatini, odatda boradi, yozadi; keyingi raqamni olib qo‘ng‘iroq qiladi.'],['BITRIX','Belgilangan raqamni nusxalaydi, 998 qo‘shadi va Telegram qidiruviga qo‘yadi. Qo‘ng‘iroq boshlanmaydi.'],['SVERKA','Raqamning o‘ng tomoniga SVERKA F2 holatini yozadi, keyingi raqamga qo‘ng‘iroq qiladi.'],['TELEGRAM','Home, keyin uch marta Delete: joriy maydonning dastlabki uch belgisi o‘chadi.'],['SAP','Belgilangan raqamni nusxalab, MicroSIP orqali 998 siz qo‘ng‘iroq qiladi.']]),
 S('SAP va BITRIX uchun tayyorgarlik','Qo‘shimcha sonlar bor butun qatorni emas, faqat telefonni belgilang. Ikki marta bosib ajratish mumkin. 9-12 ta raqam qabul qilinadi. Bo‘shliq va belgilar olib tashlanadi. 10-11 ta raqam bo‘lsa, oxirgi 9 tasi olinadi. Bu faqat formatni tozalashdir.'),
 S('Jadval ustunlari','MICROSIP holatni ikki ustun o‘ngga, SVERKA esa bir ustun o‘ngga yozadi. SVERKA dagi Enter dan keyingi o‘tish jadval tanlovining odatda pastga siljishiga tayanadi. Jadval sozlamasi boshqacha bo‘lsa, noto‘g‘ri keyingi raqam olinishi mumkin.'),
 N('TELEGRAM rejimidagi F2 boshidagi uch belgi 998 ekanini tekshirmaydi. Uni faqat kerakli maydonda bosing. NORMAL da F2 oddiy vazifasini bajaradi.')
], '04 / F2')

add('F3 - недозвон и следующий клиент','F3 - javobsiz qo‘ng‘iroq va keyingi mijoz',[
 T(['Режим','Действие F3'],[['MICROSIP','Статус F3, по умолчанию ko\'tarmadi, через два столбца справа; затем следующий звонок.'],['SVERKA','Тот же статус в соседнем столбце; затем номер следующей строки и звонок.'],['BITRIX','Активировать Telegram и удалить первые три символа текущего поля.'],['TELEGRAM','Очистить поле, перейти в таблицу, на строку вниз; вставить следующий корректный номер с 998.'],['SAP','Ввести полное имя сотрудника, указанное в F10.'],['NORMAL','Передать обычную F3 программе.']]),
 S('Запись ko\'tarmadi','Для табличного обзвона исходным активным окном должен быть MicroSIP, а предыдущим по Alt+Tab - таблица с выделенной ячейкой телефона. F3 не ищет таблицу по имени файла и не проверяет заголовок столбца статуса.'),
 S('Имя в SAP','Поставьте курсор в нужное текстовое поле и нажмите F3. Будет введено полное имя из настроек, не Telegram-подпись. Вставка не требует копирования имени и не заменяет буфер обмена.'),
 N('После автоматического перехода проверьте новую строку и номер. Если ячейка не похожа на телефон, сценарий может остановиться. F3 не означает одну и ту же операцию во всех режимах.')
],[
 T(['Rejim','F3 amali'],[['MICROSIP','F3 holati, odatda ko\'tarmadi, ikki ustun o‘ngga yoziladi; keyingi qo‘ng‘iroq boshlanadi.'],['SVERKA','Shu holat yonidagi ustunga yoziladi; keyingi qatordagi raqam teriladi.'],['BITRIX','Telegram faollashadi va joriy maydonning dastlabki uch belgisi o‘chiriladi.'],['TELEGRAM','Maydon tozalanadi, jadvalda bir qator pastga o‘tiladi; keyingi to‘g‘ri raqam 998 bilan qo‘yiladi.'],['SAP','F10 da kiritilgan xodimning to‘liq ismi yoziladi.'],['NORMAL','Dasturga oddiy F3 yuboriladi.']]),
 S('ko\'tarmadi holatini yozish','Jadval bo‘yicha qo‘ng‘iroqda MicroSIP faol oyna, telefon katagi belgilangan jadval esa Alt+Tab dagi oldingi oyna bo‘lishi kerak. F3 jadvalni fayl nomi orqali qidirmaydi va holat ustuni sarlavhasini tekshirmaydi.'),
 S('SAP dagi ism','Kursorni kerakli matn maydoniga qo‘yib F3 ni bosing. Telegram imzosi emas, sozlamadagi to‘liq ism yoziladi. Ismni oldindan nusxalash shart emas; almashuv buferi o‘zgarmaydi.'),
 N('Avtomatik o‘tishdan keyin yangi qator va raqamni tekshiring. Katak telefon raqamiga o‘xshamasa, jarayon to‘xtashi mumkin. F3 barcha rejimlarda bir xil amalni bajarmaydi.')
], '05 / F3')

add('F4 - разговор, звонок и текст SAP','F4 - suhbat, qo‘ng‘iroq va SAP matni',[
 T(['Режим','Действие F4'],[['MICROSIP','Записать статус F4, обычно gaplashilingan; следующий номер и звонок.'],['BITRIX','Очистить поле Telegram и набрать сохранённый номер в MicroSIP.'],['SVERKA','Записать Сверка F4, обычно ko\'chada; перейти к следующему номеру и позвонить.'],['TELEGRAM','Записать статус F4 через два столбца справа в таблице, взять следующий номер с 998 и вставить в Telegram.'],['SAP','Ввести готовый текст о невозможности связаться с клиентом.'],['NORMAL','Обычная F4.']]),
 S('Связка BITRIX: F2 -> F4','F2 сохраняет номер из CRM и открывает его поиск в Telegram. После проверки результата F4 использует именно сохранённый номер. Если вы вручную изменили поиск Telegram, сохранённый номер сам по себе не обновится; для нового клиента снова используйте F2.'),
 S('Текст SAP','В текущем релизе F4 вводит: Mijozni telefon raqamiga boglana olmadik. Курсор должен стоять в нужном поле. Эта фраза не редактируется в окне статусов F10; там меняются табличные статусы.'),
 N('Название статуса и учёт ответа - разные механизмы. Запись boradi или gaplashilingan в таблицу сама по себе не подтверждает ответ в аналитике. Особенности учёта описаны на странице статистики.')
],[
 T(['Rejim','F4 amali'],[['MICROSIP','F4 holati, odatda gaplashilingan, yoziladi; keyingi raqam teriladi.'],['BITRIX','Telegram maydoni tozalanadi va saqlangan raqam MicroSIP da teriladi.'],['SVERKA','SVERKA F4 holati, odatda ko\'chada, yoziladi; keyingi raqamga qo‘ng‘iroq qilinadi.'],['TELEGRAM','Jadvalda ikki ustun o‘ngga F4 holati yoziladi; keyingi raqam 998 bilan Telegramga qo‘yiladi.'],['SAP','Mijoz bilan bog‘lanib bo‘lmagani haqidagi tayyor matn yoziladi.'],['NORMAL','Oddiy F4.']]),
 S('BITRIX ketma-ketligi: F2 -> F4','F2 CRM raqamini saqlab, Telegram qidiruviga qo‘yadi. Natijani tekshirgach, F4 aynan saqlangan raqamdan foydalanadi. Telegram qidiruvidagi raqamni qo‘lda o‘zgartirish saqlangan raqamni yangilamaydi. Yangi mijoz uchun yana F2 ni ishlating.'),
 S('SAP matni','Joriy relizda F4 quyidagini yozadi: Mijozni telefon raqamiga boglana olmadik. Kursor kerakli maydonda bo‘lsin. Bu jumla F10 holatlar oynasida tahrirlanmaydi; u yerda jadvalga yoziladigan holatlar o‘zgartiriladi.'),
 N('Jadval holati va javob statistikasi alohida mexanizmlardir. boradi yoki gaplashilingan yozilishi analitikada javobni avtomatik tasdiqlamaydi. Hisoblash xususiyatlari statistika sahifasida berilgan.')
], '06 / F4')

add('F6 - перезапуск MicroSIP с DND','F6 - MicroSIP ni DND bilan qayta ochish',[
 S('Назначение','F6 закрывает MicroSIP, включает параметр DND в выбранном файле microsip.ini и запускает программу заново. Повторное нажатие не выключает DND: записывается именно значение 1. В NORMAL это обычная F6.'),
 S('Последовательность','1. Проверяются пути к программе и INI из F10.\n2. Окну отправляется закрытие; до 3 секунд ожидается выход процесса.\n3. Если MicroSIP остался в трее, процесс завершается принудительно; ожидание повторяется.\n4. После завершения записывается Settings / DND=1 и значение читается обратно.\n5. Запускается выбранный MicroSIP; до 5 секунд проверяется появление процесса.'),
 S('Что проверить оператору','Перед F6 завершите нужный разговор: перезапуск прервёт работающую телефонию. После запуска посмотрите кнопку DND и надпись «Не беспокоить» в самом MicroSIP. Albert проверяет файл и наличие процесса, но не подтверждает регистрацию SIP или доступность сервера.'),
 N('Если DND не включился, проверьте, что в F10 выбран именно INI, который использует этот MicroSIP. При неверном пути или ошибке записи появится сообщение F6; автоматического восстановления всех настроек нет.'),
 S('Когда программа была закрыта','Albert всё равно может записать DND=1 и запустить MicroSIP. Никакие SIP-аккаунты, серверы и пароли этот макрос не настраивает.')
],[
 S('Vazifasi','F6 MicroSIP ni yopadi, tanlangan microsip.ini faylida DND ni yoqadi va dasturni qayta ochadi. Takror bosish DND ni o‘chirmaydi: doim 1 qiymati yoziladi. NORMAL rejimida bu oddiy F6.'),
 S('Ketma-ketlik','1. F10 dagi dastur va INI yo‘llari tekshiriladi.\n2. Oynaga yopish buyrug‘i yuborilib, jarayon tugashi 3 soniyagacha kutiladi.\n3. MicroSIP treyda qolsa, jarayon majburan yakunlanadi va yana kutiladi.\n4. Jarayon tugagach, Settings / DND=1 yoziladi va qayta o‘qib tekshiriladi.\n5. Tanlangan MicroSIP ochiladi; jarayon paydo bo‘lishi 5 soniyagacha kutiladi.'),
 S('Operator nimani tekshiradi','F6 dan oldin kerakli suhbatni yakunlang: qayta ishga tushirish telefoniyani uzadi. Dastur ochilgach, MicroSIP ning DND tugmasi va «Не беспокоить» yozuvini tekshiring. Albert fayl va jarayonni tekshiradi, SIP ro‘yxatdan o‘tishi yoki server mavjudligini tasdiqlamaydi.'),
 N('DND yoqilmasa, F10 da aynan shu MicroSIP foydalanadigan INI tanlanganini tekshiring. Yo‘l noto‘g‘ri yoki yozish muvaffaqiyatsiz bo‘lsa, F6 xabari chiqadi. Barcha sozlamalar avtomatik tiklanmaydi.'),
 S('Dastur oldindan yopiq bo‘lsa','Albert baribir DND=1 yozib, MicroSIP ni ishga tushirishi mumkin. Bu makros SIP hisobi, server yoki parolni sozlamaydi.')
], '07 / F6')

add('F7 и F8 - вспомогательные операции','F7 va F8 - yordamchi amallar',[
 T(['Клавиша и режим','Что делает'],[['F7 / SVERKA','Копирует выделение, Alt+Tab, стрелка вниз, вставка; возвращается Alt+Tab и также опускается вниз.'],['F7 / другие рабочие режимы','Копирует выделение, открывает поиск Telegram, вводит 998 и вставляет скопированное.'],['F8 / SVERKA','Вставляет текущий буфер обмена в активное поле.'],['F8 / другие рабочие режимы','Активирует Telegram, Home и Delete три раза.'],['F7 или F8 / NORMAL','Обычное действие клавиши в программе.']]),
 S('F7 не заменяет проверку номера','В отличие от F2 в BITRIX, этот вспомогательный макрос не нормализует телефон. Если выделение уже начинается с 998, код может добавиться второй раз. Если копирование не удалось, в буфере может остаться прежний текст. Подготовьте чистый девятизначный номер.'),
 S('Работа в SVERKA','F7 рассчитана на два заранее подготовленных окна и правильные текущие ячейки. Она не ищет таблицы и не проверяет их названия. F8 просто вставляет содержимое буфера и сама не выбирает строку или клиента.'),
 N('Home + Delete три раза удаляет символы, а не «код страны» как смысловое значение. Сначала убедитесь, что курсор находится в строке поиска Telegram и первые три символа действительно нужно удалить.')
],[
 T(['Tugma va rejim','Amali'],[['F7 / SVERKA','Belgilanganni nusxalaydi, Alt+Tab, pastga o‘tish, qo‘yish; Alt+Tab bilan qaytib, yana pastga tushadi.'],['F7 / boshqa ish rejimlari','Belgilanganni nusxalaydi, Telegram qidiruvini ochadi, 998 yozib, nusxani qo‘yadi.'],['F8 / SVERKA','Joriy almashuv buferini faol maydonga qo‘yadi.'],['F8 / boshqa ish rejimlari','Telegramni faollashtiradi, Home va uch marta Delete yuboradi.'],['F7 yoki F8 / NORMAL','Dasturning odatiy tugma amali.']]),
 S('F7 raqamni tekshirish o‘rnini bosmaydi','BITRIX dagi F2 dan farqli ravishda bu yordamchi makros telefonni formatlamaydi. Belgilangan matn 998 bilan boshlansa, kod ikki marta qo‘shilishi mumkin. Nusxalash bajarilmasa, eski bufer matni qolishi mumkin. Toza to‘qqiz xonali raqam tayyorlang.'),
 S('SVERKA da ishlash','F7 oldindan tayyorlangan ikkita oyna va to‘g‘ri joriy kataklarga tayanadi. U jadvallarni qidirmaydi, nomlarini tekshirmaydi. F8 faqat buferdagi matnni qo‘yadi; qator yoki mijozni tanlamaydi.'),
 N('Home + uch marta Delete mazmunan «mamlakat kodi»ni emas, shunchaki belgilarni o‘chiradi. Avval kursor Telegram qidiruvida ekanini va dastlabki uch belgi o‘chirilishi kerakligini tekshiring.')
], '08 / F7 + F8')

add('F9 и ScrollLock - закрытие программ','F9 va ScrollLock - dasturlarni yopish',[
 S('F9: подготовка к сверке','После F9 появится вопрос. Enter в течение 3 секунд подтверждает закрытие; Escape или отсутствие ответа отменяют. В NORMAL F9 работает обычно. Подтверждённый сценарий закрывает окна Chrome с Bitrix/Битрикс/SAP/sap в заголовке и завершает MicroSIP, Telegram и калькулятор.'),
 S('Что F9 не гарантирует','Проверка браузера привязана к chrome.exe. Окна Edge этим правилом не закрываются. Закрывается окно Chrome с подходящим заголовком, поэтому соседние вкладки этого окна также могут исчезнуть. Завершение процессов может прервать звонок и несохранённую работу.'),
 S('ScrollLock: завершение работы ПК','Enter в первые 5 секунд запускает принудительное закрытие списка программ: Sublime Text, MicroSIP, Telegram, Chrome, Яндекс Браузер, калькулятор, WPS и Excel. Затем имитируется открытие диалога выключения Windows через рабочий стол, Alt+F4 и Enter. Клавиша действует и в NORMAL.'),
 N('В текущем релизе отмена ScrollLock работает с ограничением: сначала код ждёт Enter, затем без тайм-аута ждёт Escape. Короткое Escape в первые 5 секунд может быть пропущено; повторный ScrollLock не является надёжной отменой. Не используйте этот макрос для проверки «на пробу».'),
 S('Перед закрытием','Сохраните таблицы и закончите разговор. Если выключение Windows не произошло, завершите работу штатно через меню Windows. В документации описан существующий сценарий, а не гарантированное системное выключение.')
],[
 S('F9: tekshiruvga tayyorlanish','F9 dan so‘ng savol chiqadi. 3 soniya ichida Enter yopishni tasdiqlaydi; Escape yoki javob bermaslik bekor qiladi. NORMAL da F9 odatiy ishlaydi. Tasdiqlangan amal sarlavhasida Bitrix/Битрикс/SAP/sap bor Chrome oynalarini yopadi, MicroSIP, Telegram va kalkulyatorni yakunlaydi.'),
 S('F9 nimalarni kafolatlamaydi','Brauzer tekshiruvi chrome.exe ga bog‘langan. Edge oynalari bu qoida bilan yopilmaydi. Mos sarlavhali Chrome oynasi yopiladi; uning boshqa varaqlari ham yopilishi mumkin. Jarayonlarni yakunlash suhbat yoki saqlanmagan ishni uzishi mumkin.'),
 S('ScrollLock: kompyuter ishini tugatish','Dastlabki 5 soniyada Enter bosilsa, Sublime Text, MicroSIP, Telegram, Chrome, Yandex brauzeri, kalkulyator, WPS va Excel majburan yopiladi. So‘ng ish stoli orqali Alt+F4 va Enter bilan Windows o‘chirish oynasi boshqariladi. NORMAL da ham ishlaydi.'),
 N('Joriy relizda ScrollLock ni bekor qilish cheklangan: kod avval Enter ni, so‘ng vaqt cheklovisiz Escape ni kutadi. Dastlabki 5 soniyada qisqa Escape bosilishi o‘tkazib yuborilishi mumkin. ScrollLock ni yana bosish ishonchli bekor qilish usuli emas. Sinab ko‘rish uchun bu makrosni ishlatmang.'),
 S('Yopishdan oldin','Jadvallarni saqlang va suhbatni tugating. Windows o‘chmasa, Windows menyusidan odatiy usulda yakunlang. Bu yerda mavjud makros tasvirlangan; tizimning albatta o‘chishi kafolatlanmaydi.')
], '09 / F9 + SCROLLLOCK')

add('F10 - сотрудник, пути и настройки','F10 - xodim, yo‘llar va sozlamalar',[
 S('Открытие окна','F10 открывает настройки Albert в любом режиме. Тот же пункт есть в меню значка Albert в трее. Пока основное окно настроек открыто, горячие клавиши скрипта приостановлены. После закрытия обычного окна настроек они снова включаются.'),
 T(['Поле или кнопка','Назначение'],[['Полное имя','Текст, который F3 вводит в SAP.'],['Подпись Telegram','Хэштег для сообщения о товаре; можно ввести с # или без него. Пробелы не допускаются.'],['Пути программ и INI','MicroSIP, его microsip.ini, Telegram и браузер.'],['Таблицы','Размеры и адреса; оба поля можно оставить пустыми.'],['Выбрать…','Открывает выбор файла для соответствующего поля.'],['Сохранить и включить','Проверяет поля, сохраняет настройки и создаёт ярлык автозагрузки.']]),
 S('Другие кнопки','«Статусы F2/F3/F4» открывает отдельную форму статусов. «Филиалы…» открывает список соответствий склада и Telegram-группы. Эти окна описаны на следующей странице. Крестик или Escape закрывает основное окно без сохранения несохранённых изменений его полей.'),
 N('При первой настройке закрытие окна завершает Albert. Сохранение допускается из C:\\Albert. Нажатие «Сохранить и включить» не запускает программы и не раскладывает их по столам немедленно.')
],[
 S('Oynani ochish','F10 har qanday rejimda Albert sozlamalarini ochadi. Shu band Albertning treydagi menyusida ham mavjud. Asosiy sozlamalar oynasi ochiq paytda skriptning tezkor tugmalari vaqtincha to‘xtatiladi. Oddiy sozlamalar oynasi yopilgach, ular yana yoqiladi.'),
 T(['Maydon yoki tugma','Vazifasi'],[['Полное имя','SAP da F3 yozadigan to‘liq ism.'],['Подпись Telegram','Tovar xabari uchun xeshteg; # bilan yoki usiz kiriting. Bo‘shliq bo‘lmasin.'],['Dastur va INI yo‘llari','MicroSIP, uning microsip.ini fayli, Telegram va brauzer.'],['Jadvallar','O‘lchamlar va manzillar; ikkala maydon ham bo‘sh qolishi mumkin.'],['Выбрать…','Tegishli maydon uchun fayl tanlash oynasini ochadi.'],['Сохранить и включить','Maydonlarni tekshiradi, saqlaydi va avtomatik yuklanish yorlig‘ini yaratadi.']]),
 S('Boshqa tugmalar','«Статусы F2/F3/F4» alohida holatlar oynasini ochadi. «Филиалы…» ombor va Telegram guruhi mosliklarini ochadi. Ular keyingi sahifada tushuntirilgan. X yoki Escape asosiy oynani uning saqlanmagan maydonlarini saqlamasdan yopadi.'),
 N('Birinchi sozlash oynasi yopilsa, Albert yakunlanadi. Saqlash C:\\Albert papkasidan ruxsat etiladi. «Сохранить и включить» dasturlarni darhol ochmaydi va ish stollariga joylamaydi.')
], '10 / F10 SETTINGS')

add('F10 - статусы и новые филиалы','F10 - holatlar va yangi filiallar',[
 S('Форма статусов','Настраиваются пять текстов: общие F2, F3, F4 и отдельные Сверка F2, Сверка F4. Нажмите «Сохранить», чтобы записать их в settings.ini. Изменение текста не меняет назначение клавиши в BITRIX или SAP.'),
 S('Добавление филиала','1. В F10 нажмите «Филиалы…».\n2. Нажмите «Очистить поля», особенно если перед этим выбирали существующий филиал.\n3. Введите точное название склада из CRM и точное название группы Telegram.\n4. Нажмите «Добавить / сохранить изменение». Список сохраняется сразу, отдельное сохранение в главном окне не требуется.'),
 T(['Склад','Группа Telegram'],[['CT2 - ASKO Chust','Chust filiali CALL SENTR'],['AN - ASKO Andijon','ANDIJON ASKO'],['AR - ASKO Angren','Angren call center'],['QR2 - ASKO Qarshi 2','QARSHI 2 FILIAL']]),
 S('Изменение и удаление','Выберите строку, исправьте поля и нажмите сохранение. При переименовании старая запись заменяется. Кнопка «Удалить выбранный» требует подтверждения Yes. «Очистить поля» ничего не удаляет. Дубликат названия склада при добавлении отклоняется.'),
 N('Неизвестный или удалённый филиал останавливает автоматическую отправку товара. Названия не должны содержать =, квадратные скобки или переносы строк. Проверьте доступ сотрудника к группе Telegram до использования макроса.')
],[
 S('Holatlar oynasi','Beshta matn sozlanadi: umumiy F2, F3, F4 va alohida SVERKA F2, SVERKA F4. Ularni settings.ini ga yozish uchun «Сохранить» ni bosing. Matnni o‘zgartirish BITRIX yoki SAP dagi tugma vazifasini o‘zgartirmaydi.'),
 S('Filial qo‘shish','1. F10 da «Филиалы…» ni oching.\n2. Ayniqsa mavjud filialni tanlagan bo‘lsangiz, «Очистить поля» ni bosing.\n3. CRM dagi ombor nomini va Telegram guruhining aniq nomini kiriting.\n4. «Добавить / сохранить изменение» ni bosing. Ro‘yxat darhol saqlanadi; asosiy oynada yana saqlash shart emas.'),
 T(['Ombor','Telegram guruhi'],[['CT2 - ASKO Chust','Chust filiali CALL SENTR'],['AN - ASKO Andijon','ANDIJON ASKO'],['AR - ASKO Angren','Angren call center'],['QR2 - ASKO Qarshi 2','QARSHI 2 FILIAL']]),
 S('Tahrirlash va o‘chirish','Qatorni tanlang, maydonlarni tuzating va saqlang. Nom o‘zgarsa, eski yozuv almashtiriladi. «Удалить выбранный» Yes bilan tasdiqlashni so‘raydi. «Очистить поля» yozuvni o‘chirmaydi. Yangi filial qo‘shishda takroriy ombor nomi rad etiladi.'),
 N('Noma’lum yoki o‘chirilgan filial tovar xabarini avtomatik yuborishni to‘xtatadi. Nomlarda =, kvadrat qavslar yoki yangi qator bo‘lmasin. Makrosdan oldin xodim Telegram guruhiga kira olishini tekshiring.')
], '11 / BRANCHES')

add('Продажи: Volume_Mute и PrintScreen','Savdolar: Volume_Mute va PrintScreen',[
 S('Volume_Mute: зарегистрировать продажу','Это клавиша отключения звука на клавиатуре. В рабочем режиме Albert использует её для продажи: Win+1 активирует MicroSIP, Enter отправляется для завершения звонка, дневной счётчик увеличивается на 1. Сохраняется также счётчик продаж текущего часа. Затем Win+3 активирует браузер.'),
 S('Связь с текущим звонком','Если в аналитике есть активный звонок, он завершается с результатом SALE. Если активного звонка нет, дневной и часовой счётчики всё равно увеличиваются. Поэтому каждое случайное нажатие может добавить продажу, даже если разговора не было.'),
 S('PrintScreen: уменьшить дневной итог','В рабочем режиме PrintScreen уменьшает число продаж текущего дня на 1, но не ниже нуля. Это не обычный снимок экрана. В NORMAL обе клавиши возвращаются к стандартным действиям: отключению звука и PrintScreen.'),
 N('Ограничение релиза: PrintScreen не отменяет связанную запись звонка и не уменьшает почасовой счётчик. Дневная цифра после исправления может расходиться с почасовой аналитикой. Это не точная отмена последней продажи.'),
 S('Пример','Если дневной счётчик показывает 6, нажатие Volume_Mute даст 7. Случайное добавление можно исправить PrintScreen до 6, но часовой показатель автоматически не вернётся назад. Не исправляйте журнал вручную без резервной копии.')
],[
 S('Volume_Mute: savdoni qayd etish','Bu klaviaturadagi ovozni o‘chirish tugmasi. Ish rejimida Albert uni savdo uchun ishlatadi: Win+1 MicroSIP ni faollashtiradi, qo‘ng‘iroqni tugatish uchun Enter yuboriladi va kunlik hisob 1 taga oshadi. Joriy soat savdo hisobi ham saqlanadi. So‘ng Win+3 brauzerni faollashtiradi.'),
 S('Joriy qo‘ng‘iroq bilan bog‘lanishi','Analitikada faol qo‘ng‘iroq bo‘lsa, u SALE natijasi bilan yakunlanadi. Faol qo‘ng‘iroq bo‘lmasa ham kunlik va soatlik hisob oshadi. Shuning uchun tasodifiy bosish suhbat bo‘lmaganida ham savdo qo‘shishi mumkin.'),
 S('PrintScreen: kunlik natijani kamaytirish','Ish rejimida PrintScreen joriy kun savdolarini 1 taga kamaytiradi, lekin noldan pastga tushirmaydi. Bu oddiy ekran tasviri olish emas. NORMAL da ikkala tugma odatiy vazifasiga qaytadi: ovozni o‘chirish va PrintScreen.'),
 N('Reliz cheklovi: PrintScreen bog‘langan qo‘ng‘iroq yozuvini bekor qilmaydi va soatlik hisobni kamaytirmaydi. Tuzatilgan kunlik son soatlik analitikadan farq qilishi mumkin. Bu oxirgi savdoni aniq bekor qilish amali emas.'),
 S('Misol','Kunlik hisob 6 bo‘lsa, Volume_Mute uni 7 qiladi. Tasodifiy qo‘shilishni PrintScreen orqali 6 ga qaytarish mumkin, lekin soatlik ko‘rsatkich avtomatik qaytmaydi. Zaxira nusxasiz jurnalni qo‘lda tahrirlamang.')
], '12 / SALES')

add('Insert и Home - статистика','Insert va Home - statistika',[
 S('Insert: последние десять дней','Открывает график дневных продаж за последние 10 дней. Значения берутся из settings.ini. Кнопка «Закрыть» закрывает график. В NORMAL Insert работает как обычная клавиша.'),
 S('Home: аналитика рабочего дня','Открывает отчёт за выбранную дату. Дата вводится в формате YYYY-MM-DD, например 2026-09-25. «Показать» обновляет отчёт; стрелки переходят на соседние дни, «Сегодня» возвращает текущую дату, «Закрыть» закрывает окно. В NORMAL Home возвращается к обычному действию.'),
 T(['Показатель','Как читать'],[['Звонки / уникальные клиенты','Попытки начала звонка и разные нормализованные номера. Повторы увеличивают число звонков.'],['Ответы','События подтверждения ответа, а не прямые данные SIP-сервера.'],['Конверсия','Дневные продажи, делённые на число начатых звонков.'],['Простой > 5 минут','Промежутки между записанными действиями; это не доказательство бездействия сотрудника.'],['Средний интервал','Время между началами звонков, не средняя длительность разговора.']]),
 N('Ответ отмечает сценарий Launch_Media при подходящем активном номере. Если им не пользоваться, реальные ответы могут остаться неучтёнными. Продажа без активного звонка и отмена через PrintScreen также дают расхождения. Аналитика отражает действия макросов, а не телефонный биллинг.')
],[
 S('Insert: oxirgi o‘n kun','Oxirgi 10 kunlik savdolar grafigini ochadi. Qiymatlar settings.ini dan olinadi. «Закрыть» grafikni yopadi. NORMAL da Insert odatiy tugma bo‘lib ishlaydi.'),
 S('Home: ish kuni analitikasi','Tanlangan sana uchun hisobotni ochadi. Sana YYYY-MM-DD shaklida kiritiladi, masalan 2026-09-25. «Показать» hisobotni yangilaydi; strelkalar qo‘shni kunlarga o‘tadi, «Сегодня» bugungi sanani qaytaradi, «Закрыть» oynani yopadi. NORMAL da Home odatiy ishlaydi.'),
 T(['Ko‘rsatkich','Mazmuni'],[['Qo‘ng‘iroqlar / noyob mijozlar','Boshlangan urinishlar va turli formatlangan raqamlar. Takroriy urinishlar qo‘ng‘iroqlar sonini oshiradi.'],['Javoblar','Javob tasdiqlangan hodisalar; SIP serverining bevosita ma’lumoti emas.'],['Konversiya','Kunlik savdolar sonining boshlangan qo‘ng‘iroqlar soniga nisbati.'],['5 daqiqadan uzun tanaffus','Qayd etilgan amallar oralig‘i; xodim ishlamaganining isboti emas.'],['O‘rtacha interval','Qo‘ng‘iroqlar boshlanishlari oralig‘i; suhbatning o‘rtacha davomiyligi emas.']]),
 N('Mos faol raqam bo‘lsa, Launch_Media javobni belgilaydi. Bu makros ishlatilmasa, haqiqiy javoblar hisoblanmay qolishi mumkin. Faol qo‘ng‘iroqsiz savdo va PrintScreen bilan tuzatish ham tafovut beradi. Analitika telefoniya billingini emas, makros amallarini aks ettiradi.')
], '13 / ANALYTICS')

add('Мультимедиа и остальные клавиши','Multimedia va boshqa tugmalar',[
 T(['Клавиша','Назначение'],[['Volume_Down','Предыдущий рабочий стол: Ctrl+Win+Left.'],['Volume_Up','Следующий рабочий стол: Ctrl+Win+Right.'],['Browser_Home','Ctrl+W в активном окне, затем рабочий стол влево.'],['PgDn','Win+R, ввод cmd, Enter: открывает командную строку.'],['PgUp','Обычная клавиша; макрос логина и пароля удалён.'],['F5 / Pause','В Albert нет собственного обработчика; действие определяет программа или Windows.']]),
 S('Launch_Media: подготовка номера в Telegram','Специальная клавиша запуска медиаприложения берёт цифры из буфера. Если цифр 10 или больше, оставляет последние 9. Активирует Telegram через Win+2, выполняет Escape, поиск и навигацию Down два раза / Enter, вставляет номер с пробелом и переключает стол вправо. Сообщение этим шагом ещё не отправляется.'),
 S('Настройка раскладки Telegram','Макрос выбирает чат по позиции, а не по имени. До работы убедитесь, что последовательность открывает вашу нужную группу. Не путайте Launch_Media с обычной кнопкой Play/Pause: на некоторых клавиатурах отдельной Launch_Media нет.'),
 N('Volume_Up/Down, Browser_Home, PgDn и Launch_Media действуют даже в NORMAL. Кнопки громкости при активном Albert переключают столы. Browser_Home может закрыть текущую вкладку или документ. Для обычного поведения полностью завершите Albert.')
],[
 T(['Tugma','Vazifasi'],[['Volume_Down','Oldingi ish stoli: Ctrl+Win+Left.'],['Volume_Up','Keyingi ish stoli: Ctrl+Win+Right.'],['Browser_Home','Faol oynaga Ctrl+W, keyin chapdagi ish stoliga o‘tish.'],['PgDn','Win+R, cmd, Enter: buyruq satrini ochadi.'],['PgUp','Oddiy tugma; login va parol makrosi olib tashlangan.'],['F5 / Pause','Albertning maxsus ishlovchisi yo‘q; vazifani dastur yoki Windows belgilaydi.']]),
 S('Launch_Media: Telegramga raqam tayyorlash','Media dasturini ochish uchun maxsus tugma buferdagi raqamlarni oladi. 10 ta yoki ko‘proq bo‘lsa, oxirgi 9 tasi qoldiriladi. Win+2 bilan Telegramni faollashtirib, Escape, qidiruv va ikki marta Down / Enter ketma-ketligini bajaradi. Raqam va bo‘shliq kiritilgach, o‘ngdagi stolga o‘tadi. Bu bosqichda xabar hali yuborilmaydi.'),
 S('Telegram tartibini tayyorlash','Makros chatni nomi bo‘yicha emas, ro‘yxatdagi o‘rni orqali tanlaydi. Ishdan oldin shu ketma-ketlik kerakli guruhni ochishini tekshiring. Launch_Media oddiy Play/Pause tugmasi emas. Ayrim klaviaturalarda alohida Launch_Media bo‘lmaydi.'),
 N('Volume_Up/Down, Browser_Home, PgDn va Launch_Media NORMAL da ham ishlaydi. Albert faol bo‘lsa, ovoz tugmalari ish stollarini almashtiradi. Browser_Home joriy varaq yoki hujjatni yopishi mumkin. Odatiy ishlash uchun Albertdan to‘liq chiqing.')
], '14 / EXTRA KEYS')

add('Тильда / Ё: выбор товара','Tilda / Ё: tovarni tanlash',[
 S('Какая клавиша используется','SC029 - физическая клавиша слева от цифры 1, обычно Ё / ` / ~. В NORMAL вводится обычный символ. В SVERKA и SAP она управляет Play/Pause независимо от раскладки. В остальных рабочих режимах русская раскладка вводит ё/Ё, а нерусская запускает сценарий товара. Для работы используйте английскую раскладку.'),
 S('Как выделять строку склада','Выделите полный первый товар: название склада, код SHN… или DK…, продукцию с размером, цену UZS и остаток в «шт». Можно захватить несколько строк, но используется только первая. Если первая строка обрезана, не рассчитывайте, что Albert возьмёт вместо неё следующую.'),
 T(['Элемент','Пример'],[['Склад','QR2 - ASKO Qarshi 2'],['Название и размер шины','Fortuna ECOPLUS2 4S 175/70/13'],['Диск','Qora Diska 114,3/B/13'],['Цена и остаток','418 000 UZS; 8 шт']]),
 S('Проверки перед отправкой','Нужно не менее 4 штук. При 3 и меньше появляется сообщение и операция прекращается. Нераспознанные цена, размер, остаток или неизвестный филиал тоже останавливают сценарий. Другие коды товара и другие форматы размеров могут не поддерживаться.'),
 N('Цена считается в тысячах сумов: 418 000 UZS -> 418 × 4 = 1672, то есть 1 672 000 сумов. Стоимость показывается калькулятором; в текст сообщения она автоматически не добавляется.')
],[
 S('Qaysi tugma ishlatiladi','SC029 - 1 raqamining chapidagi jismoniy tugma, odatda Ё / ` / ~. NORMAL da oddiy belgi yoziladi. SVERKA va SAP da klaviatura tilidan qat’i nazar Play/Pause ishlaydi. Boshqa ish rejimlarida ruscha til ё/Ё yozadi, ruscha bo‘lmagan til tovar jarayonini boshlaydi. Ish uchun inglizcha tilni tanlang.'),
 S('Ombor qatorini qanday belgilash kerak','Birinchi tovarni to‘liq belgilang: ombor nomi, SHN… yoki DK… kodi, o‘lchamli mahsulot nomi, UZS narxi va «шт» bilan qoldiq. Bir nechta qator belgilansa ham faqat birinchisi olinadi. Birinchi qator chala bo‘lsa, Albert uning o‘rniga keyingisini oladi deb kutmang.'),
 T(['Qism','Misol'],[['Ombor','QR2 - ASKO Qarshi 2'],['Shina nomi va o‘lchami','Fortuna ECOPLUS2 4S 175/70/13'],['Disk','Qora Diska 114,3/B/13'],['Narx va qoldiq','418 000 UZS; 8 шт']]),
 S('Yuborishdan oldingi tekshiruvlar','Kamida 4 dona kerak. 3 yoki undan kam bo‘lsa, xabar chiqib jarayon to‘xtaydi. Narx, o‘lcham yoki qoldiq o‘qilmasa, yoxud filial noma’lum bo‘lsa ham jarayon to‘xtaydi. Boshqa mahsulot kodlari va o‘lcham shakllari qo‘llab-quvvatlanmasligi mumkin.'),
 N('Narx ming so‘mda hisoblanadi: 418 000 UZS -> 418 × 4 = 1672, ya’ni 1 672 000 so‘m. Natija kalkulyatorda ko‘rinadi; narx xabar matniga avtomatik qo‘shilmaydi.')
], '15 / SC029: PRODUCT')

add('Тильда / Ё: отправка в две группы','Tilda / Ё: ikki guruhga yuborish',[
 S('Подготовьте текущую группу','На столе 2 откройте Telegram в нужной рабочей группе, например sotuv. В поле сообщения уже должен стоять номер клиента, а курсор должен быть в этом поле. Albert не ищет эту первую группу по имени и не набирает номер заново.'),
 S('Полный порядок действий','1. На столе 3 выделите товар и нажмите тильду.\n2. Albert разбирает первую строку, проверяет остаток и филиал.\n3. Win+4 открывает калькулятор для цены комплекта.\n4. Переход на стол влево и Win+2 возвращают Telegram.\n5. К номеру дописываются название, размер и подпись из F10.\n6. Ctrl+A, Ctrl+C и Enter копируют и отправляют весь текст в текущую группу.\n7. Через поиск открывается группа филиала и отправляется тот же текст.\n8. Скрипт возвращается на стол склада.'),
 S('Формат сообщения','НОМЕР_КЛИЕНТА  Fortuna ECOPLUS2 4S 175/70/13 #Имя\nПодпись берётся из F10. В реальной работе вместо учебного обозначения уже должен быть введён номер.'),
 N('Отправка автоматическая, без отдельного подтверждения. После начала не меняйте фокус и не нажимайте клавиши. При медленном поиске или совпадающих именах групп нужно проверить реальных получателей: код не проверяет идентификатор открытого чата.'),
 S('Если операция оборвалась','Сначала посмотрите историю обеих групп. Не повторяйте весь макрос сразу: первая отправка могла уже состояться. Ошибка копирования останавливает отправку, а сообщение об успехе само по себе не является подтверждением доставки Telegram.')
],[
 S('Joriy guruhni tayyorlang','2-stolda Telegramning kerakli ish guruhini, masalan sotuv ni oching. Xabar maydonida mijoz raqami allaqachon bo‘lsin va kursor shu maydonda tursin. Albert birinchi guruhni nomi bilan qidirmaydi va raqamni qayta kiritmaydi.'),
 S('To‘liq amallar tartibi','1. 3-stolda tovarni belgilang va tildani bosing.\n2. Albert birinchi qatorni o‘qib, qoldiq va filialni tekshiradi.\n3. Win+4 kalkulyatorni ochib, to‘plam narxini hisoblaydi.\n4. Chapdagi stolga o‘tish va Win+2 Telegramni qaytaradi.\n5. Raqam yoniga nom, o‘lcham va F10 dagi imzo qo‘shiladi.\n6. Ctrl+A, Ctrl+C va Enter matnni nusxalab, joriy guruhga yuboradi.\n7. Qidiruvdan filial guruhi ochilib, ayni matn yuboriladi.\n8. Skript ombor stoliga qaytadi.'),
 S('Xabar shakli','MIJOZ_RAQAMI  Fortuna ECOPLUS2 4S 175/70/13 #Ism\nImzo F10 dan olinadi. Haqiqiy ishda o‘quv belgilanishi o‘rnida oldindan kiritilgan mijoz raqami turishi kerak.'),
 N('Yuborish alohida tasdiqsiz, avtomatik bajariladi. Jarayon boshlanganidan keyin fokusni almashtirmang va tugmalarni bosmang. Qidiruv sekin yoki guruh nomlari o‘xshash bo‘lsa, haqiqiy oluvchilarni tekshiring: kod chat identifikatorini tekshirmaydi.'),
 S('Jarayon uzilib qolsa','Avval ikkala guruh tarixini ko‘ring. Makrosni darhol to‘liq takrorlamang: birinchi xabar yuborilgan bo‘lishi mumkin. Nusxalash xatosi yuborishni to‘xtatadi. Muvaffaqiyat xabari Telegram yetkazib berganini tasdiqlamaydi.')
], '16 / SC029: TELEGRAM')

add('Рабочие сценарии и таблицы','Ish jarayonlari va jadvallar',[
 S('Клиент из Bitrix','Выберите BITRIX через F11. Выделите телефон в CRM, нажмите F2 и проверьте поиск Telegram. Для удаления 998 при необходимости используйте F3, предварительно проверив поле. F4 набирает сохранённый номер через MicroSIP, F1 делает повторную попытку.'),
 S('Обзвон списка','Для MICROSIP подготовьте таблицу: телефон, промежуточный столбец, статус. Для SVERKA: телефон, статус. Во время звонка активен MicroSIP, таблица - предыдущее окно Alt+Tab. Клавиши F2/F3/F4 записывают нужный результат и переходят дальше. Порядок строк не сортируется автоматически.'),
 S('Что делает поиск номера','Общий поиск в MICROSIP/TELEGRAM проверяет до 15 позиций. Две пустые ячейки подряд останавливают поиск. Некорректная непустая ячейка помечается Error через два столбца справа, затем поиск идёт вниз. В SVERKA следующий номер копируется напрямую; такого полного поиска нет.'),
 S('Сотрудник в SAP','F12 до SAP. Выделение номера -> F2; повтор -> F1. F3 вводит полное имя, F4 - готовую фразу о недозвоне. Сначала поставьте курсор в соответствующее поле, иначе текст попадёт в другое место.'),
 N('Открытые через запуск таблицы размеров и адресов не становятся автоматически таблицей обзвона. Макросы работают с текущим выделением и Alt+Tab, а не с файлами из полей F10. Не меняйте окна во время последовательности.')
],[
 S('Bitrix dan mijoz','F11 orqali BITRIX ni tanlang. CRM telefonini belgilang, F2 ni bosing va Telegram qidiruvini tekshiring. 998 ni olib tashlash kerak bo‘lsa, maydonni tekshirib F3 dan foydalaning. F4 saqlangan raqamni MicroSIP orqali teradi, F1 takroriy urinish qiladi.'),
 S('Ro‘yxat bo‘yicha qo‘ng‘iroq','MICROSIP uchun jadval: telefon, oraliq ustun, holat. SVERKA uchun: telefon, holat. Suhbat paytida MicroSIP faol, jadval esa Alt+Tab dagi oldingi oyna bo‘lsin. F2/F3/F4 natijani yozib keyingisiga o‘tadi. Qatorlar avtomatik saralanmaydi.'),
 S('Raqam qidiruvi qanday ishlaydi','MICROSIP/TELEGRAM dagi umumiy qidiruv 15 tagacha joyni tekshiradi. Ketma-ket ikki bo‘sh katak qidiruvni to‘xtatadi. Bo‘sh bo‘lmagan noto‘g‘ri katakdan ikki ustun o‘ngga Error yoziladi, so‘ng pastga o‘tiladi. SVERKA da keyingi raqam bevosita nusxalanadi; bunday to‘liq qidiruv yo‘q.'),
 S('SAP da xodim','F12 bilan SAP ga o‘ting. Raqamni belgilash -> F2; takrorlash -> F1. F3 to‘liq ismni, F4 bog‘lanib bo‘lmagani haqidagi jumlani yozadi. Avval kursorni kerakli maydonga qo‘ying, aks holda matn boshqa joyga tushadi.'),
 N('Ishga tushirishda ochilgan o‘lcham va manzil jadvallari avtomatik qo‘ng‘iroq ro‘yxatiga aylanmaydi. Makroslar F10 dagi fayllar bilan emas, joriy belgilash va Alt+Tab bilan ishlaydi. Jarayon vaqtida oynalarni almashtirmang.')
], '17 / DAILY WORK')

add('Ошибки и ограничения релиза','Reliz xatolari va cheklovlari',[
 T(['Симптом','Что проверить'],[['Открывается чужая программа','Порядок Win+1/2/3/4: MicroSIP, Telegram, браузер, калькулятор.'],['В таблице меняется не та строка','Активную ячейку, режим, расстояние до статуса и предыдущее окно Alt+Tab.'],['Тильда пишет ё или ставит паузу','Русская раскладка, SVERKA или SAP. Для товара нужен подходящий режим и английская раскладка.'],['«Филиал не настроен»','Точное имя склада в F10 -> «Филиалы…».'],['После F6 нет нужного DND','Выбранные EXE и INI должны принадлежать одной установке MicroSIP.'],['После запуска окна на другом столе','Приложение могло уже быть открыто отдельной автозагрузкой или Windows.']]),
 S('Безопасное восстановление','Прекратите повторные нажатия. Проверьте, что уже сделано: запись статуса, звонок, сообщения в группах. Восстановите нужные окна и поля вручную. Для полного прекращения макросов выйдите из Albert через трей; End не выключает все обработчики.'),
 S('Что передать поддержке','Клавиша, режим, активное приложение, шаг остановки, текст подсказки и время события. При необходимости приложите только относящийся к событию фрагмент activity_log.txt. Журнал может содержать номера клиентов.'),
 N('Релиз проверен синтаксически и изолированными тестами логики. Реальный вход в Windows, размещение окон и отправка сообщений требуют проверки на целевом ПК. Приведённые ограничения не исправляются изменением инструкции.')
],[
 T(['Belgi','Nimani tekshirish kerak'],[['Boshqa dastur ochiladi','Win+1/2/3/4 tartibi: MicroSIP, Telegram, brauzer, kalkulyator.'],['Jadvalda boshqa qator o‘zgaradi','Faol katak, rejim, holat ustunigacha masofa va Alt+Tab dagi oldingi oyna.'],['Tilda ё yozadi yoki pauza qiladi','Ruscha klaviatura, SVERKA yoki SAP. Tovar uchun mos rejim va inglizcha til kerak.'],['«Филиал не настроен»','F10 -> «Филиалы…» dagi omborning aniq nomi.'],['F6 dan keyin DND noto‘g‘ri','Tanlangan EXE va INI bir xil MicroSIP o‘rnatilishiga tegishli bo‘lsin.'],['Oynalar boshqa stolda','Dastur alohida avtomatik yuklanish yoki Windows orqali avval ochilgan bo‘lishi mumkin.']]),
 S('Ishni to‘g‘ri tiklash','Takroriy bosishni to‘xtating. Nimalar bajarilganini ko‘ring: holat yozuvi, qo‘ng‘iroq, guruhlardagi xabarlar. Kerakli oynalar va maydonlarni qo‘lda tiklang. Makroslarni to‘liq to‘xtatish uchun treydan Albertdan chiqing; End barcha ishlovchilarni o‘chirmaydi.'),
 S('Yordam xizmatiga nimalar kerak','Tugma, rejim, faol dastur, to‘xtagan bosqich, xabar matni va hodisa vaqti. Kerak bo‘lsa, activity_log.txt ning faqat tegishli qismini yuboring. Jurnalda mijoz raqamlari bo‘lishi mumkin.'),
 N('Reliz sintaksis va alohida mantiq testlari bilan tekshirilgan. Windows ga haqiqiy kirish, oynalar joylashuvi va xabar yuborish maqsadli kompyuterda tekshirilishi kerak. Ko‘rsatilgan cheklovlar qo‘llanma matni bilan tuzalmaydi.')
], '18 / SUPPORT')

add('Установка: подготовка другого ПК','O‘rnatish: boshqa kompyuterni tayyorlash',[
 S('Необходимые программы','Windows 10/11 и AutoHotkey именно v2. Установите MicroSIP, Telegram Desktop и Chrome либо Edge. Для необязательных таблиц потребуется Excel или совместимая программа. Albert не устанавливает эти приложения и не создаёт аккаунты за сотрудника.'),
 S('Подготовьте доступы','В MicroSIP настройте SIP-аккаунт и проверьте обычный звонок. В Telegram войдите под нужным аккаунтом и проверьте группы. В выбранном браузере авторизуйтесь в Bitrix и проверьте склад. Учётные данные MicroSIP и Telegram не вводятся в мастер Albert.'),
 S('Общие адреса','Bitrix: https://ababin.bitrix24.kz/crm/deal/kanban/category/0/\nСклад: http://185.100.53.213:3000/warehouse-balance-report-crm#\nОба адреса встроены в релиз и не редактируются через F10.'),
 S('Файлы установки','Создайте C:\\Albert и положите туда релизный Albert-V2.ahk. Можно положить рядом эту инструкцию. Не переносите settings.ini и activity_log.txt другого сотрудника: первая настройка должна быть индивидуальной. Скрипт не копирует себя автоматически из Downloads или Telegram в C:\\Albert.'),
 N('У пользователя должен быть доступ на запись в C:\\Albert. Если создание папки запрещено политикой ПК, попросите администратора подготовить её и права. Не меняйте папку установки в обход проверки мастера.')
],[
 S('Kerakli dasturlar','Windows 10/11 va aynan AutoHotkey v2 kerak. MicroSIP, Telegram Desktop hamda Chrome yoki Edge ni o‘rnating. Ixtiyoriy jadvallar uchun Excel yoki mos dastur kerak bo‘ladi. Albert bu dasturlarni o‘rnatmaydi va xodim uchun hisob yaratmaydi.'),
 S('Kirishlarni tayyorlang','MicroSIP da SIP hisobini sozlab, oddiy qo‘ng‘iroqni tekshiring. Telegramda kerakli hisobga kiring va guruhlarni tekshiring. Tanlangan brauzerda Bitrix ga kiring va omborni ochib ko‘ring. MicroSIP va Telegram parollari Albert ustasiga kiritilmaydi.'),
 S('Umumiy manzillar','Bitrix: https://ababin.bitrix24.kz/crm/deal/kanban/category/0/\nOmbor: http://185.100.53.213:3000/warehouse-balance-report-crm#\nIkkala manzil reliz ichida yozilgan va F10 orqali tahrirlanmaydi.'),
 S('O‘rnatish fayllari','C:\\Albert yarating va relizdagi Albert-V2.ahk ni shu yerga qo‘ying. Qo‘llanmani ham yoniga qo‘yish mumkin. Boshqa xodimning settings.ini va activity_log.txt fayllarini ko‘chirmang: birinchi sozlash individual bo‘lsin. Skript Downloads yoki Telegram papkasidan o‘zini avtomatik ko‘chirmaydi.'),
 N('Foydalanuvchida C:\\Albert ga yozish huquqi bo‘lishi kerak. Kompyuter siyosati papka yaratishga ruxsat bermasa, administratordan papka va huquqlarni tayyorlashni so‘rang. Usta tekshiruvini chetlab, boshqa joyga o‘rnatmang.')
], '19 / INSTALLATION')

add('Установка: первый запуск','O‘rnatish: birinchi ishga tushirish',[
 S('Порядок значков обязателен','Закрепите приложения слева направо: MicroSIP, Telegram, выбранный браузер, калькулятор. Проверьте отдельно Win+1, Win+2, Win+3 и Win+4. Имеются в виду позиции приложений на панели задач, а не номера виртуальных столов.'),
 S('Заполните мастер','1. Дважды щёлкните C:\\Albert\\Albert-V2.ahk. Если запускается редактор, выберите открытие через AutoHotkey v2.\n2. Введите полное имя для SAP и отдельную Telegram-подпись.\n3. Проверьте найденные пути MicroSIP, Telegram и Chrome. Edge при необходимости выберите вручную.\n4. Укажите фактический microsip.ini. Обычно он в %APPDATA%\\MicroSIP\\microsip.ini.\n5. Выберите таблицы размеров и адресов или оставьте их пустыми.\n6. Нажмите «Сохранить и включить».'),
 S('Где взять путь INI','Нажмите Win+R и откройте %APPDATA%\\MicroSIP. В мастере используйте «Выбрать…» и выберите microsip.ini. Для переносной установки MicroSIP фактический файл может быть в другой папке. F6 будет изменять именно выбранный INI.'),
 N('После сохранения создаётся Albert.lnk в автозагрузке текущего пользователя. Программы сразу не открываются. Если закрыть мастер первого запуска без сохранения, Albert завершится; запустите его снова для настройки.'),
 S('Проверьте данные','Подпись допускает буквы, цифры и подчёркивание; # добавится автоматически. Полное имя и подпись независимы. Личные настройки сохраняются в settings.ini рядом со скриптом.')
],[
 S('Belgilar tartibi majburiy','Dasturlarni chapdan o‘ngga mahkamlang: MicroSIP, Telegram, tanlangan brauzer, kalkulyator. Win+1, Win+2, Win+3 va Win+4 ni alohida tekshiring. Bular virtual stollar raqami emas, vazifalar panelidagi dastur o‘rinlaridir.'),
 S('Ustani to‘ldiring','1. C:\\Albert\\Albert-V2.ahk ni ikki marta bosing. Muharrir ochilsa, AutoHotkey v2 orqali ochishni tanlang.\n2. SAP uchun to‘liq ism va alohida Telegram imzosini kiriting.\n3. Topilgan MicroSIP, Telegram va Chrome yo‘llarini tekshiring. Kerak bo‘lsa, Edge ni qo‘lda tanlang.\n4. Haqiqiy microsip.ini ni ko‘rsating. Odatda u %APPDATA%\\MicroSIP\\microsip.ini da bo‘ladi.\n5. O‘lcham va manzil jadvallarini tanlang yoki bo‘sh qoldiring.\n6. «Сохранить и включить» ni bosing.'),
 S('INI yo‘lini topish','Win+R ni bosib %APPDATA%\\MicroSIP ni oching. Ustada «Выбрать…» orqali microsip.ini ni tanlang. MicroSIP ko‘chma o‘rnatilgan bo‘lsa, fayl boshqa papkada bo‘lishi mumkin. F6 aynan tanlangan INI ni o‘zgartiradi.'),
 N('Saqlangach, joriy foydalanuvchi avtomatik yuklanish papkasida Albert.lnk yaratiladi. Dasturlar darhol ochilmaydi. Birinchi ustani saqlamasdan yopsangiz, Albert tugaydi; sozlash uchun yana ishga tushiring.'),
 S('Ma’lumotlarni tekshiring','Imzoda harf, raqam va pastki chiziq mumkin; # avtomatik qo‘shiladi. To‘liq ism va imzo mustaqil. Shaxsiy sozlamalar skript yonidagi settings.ini ga saqlanadi.')
], '20 / FIRST RUN')

add('Установка: автозагрузка и проверка','O‘rnatish: avtomatik yuklanish va tekshiruv',[
 S('Подготовка автозагрузки','Если есть старый start.ahk, уберите его из автозагрузки вручную. Отключите отдельный запуск Telegram/MicroSIP и восстановление рабочих окон Windows, если они мешают раскладке. Albert не удаляет чужие элементы автозагрузки и не переносит уже открытые окна между столами.'),
 S('Проверка входа в Windows','Выйдите из учётной записи и войдите снова. Примерно через 10 секунд после старта Albert начнётся раскладка. Не меняйте окна во время её выполнения. Недостающие столы создаются, лишние не удаляются. Завершение - на столе 2. Обычный ручной запуск скрипта программы заново не открывает.'),
 T(['Стол','Ожидаемый результат'],[['1','Albert ничего не запускает; уже открытые окна не закрывает.'],['2','Telegram, MicroSIP и окно Bitrix.'],['3','Калькулятор и отдельное окно склада.'],['4','Только указанные таблицы; при пустых полях ничего.']]),
 S('Приёмка и обновление','Проверьте индикатор режима, F10, правильную подпись, список филиалов и порядок Win+1/2/3/4. Согласованные пробные звонки и сообщения выполняйте только после проверки адресатов. Для обновления заменяйте только Albert-V2.ahk, сохраняя settings.ini и activity_log.txt, затем перезапустите скрипт.'),
 N('Для отключения автозагрузки откройте Win+R -> shell:startup и удалите Albert.lnk. Для переноса на новый ПК снова выполните индивидуальную настройку. Не запускайте одновременно старую и новую копии из разных папок.')
],[
 S('Avtomatik yuklanishni tayyorlash','Eski start.ahk bo‘lsa, uni avtomatik yuklanishdan qo‘lda olib tashlang. Joylashuvga xalaqit bersa, Telegram/MicroSIP ning alohida yuklanishi va Windows oynalarni tiklashini o‘chiring. Albert boshqa yuklanish yozuvlarini o‘chirmaydi va ochiq oynalarni stollar orasida ko‘chirmaydi.'),
 S('Windows ga kirishni tekshirish','Hisobdan chiqib, yana kiring. Albert boshlanganidan taxminan 10 soniya o‘tib oynalar ochila boshlaydi. Jarayon davomida oynalarni almashtirmang. Yetishmaydigan stollar yaratiladi, ortiqchalari o‘chirilmaydi. Oxirida 2-stol ochiladi. Skriptni qo‘lda qayta ochish dasturlarni yana ochmaydi.'),
 T(['Stol','Kutiladigan natija'],[['1','Albert hech narsa ochmaydi; mavjud oynalarni yopmaydi.'],['2','Telegram, MicroSIP va Bitrix oynasi.'],['3','Kalkulyator va omborning alohida oynasi.'],['4','Faqat ko‘rsatilgan jadvallar; bo‘sh maydonlarda hech narsa.']]),
 S('Qabul qilish va yangilash','Rejim indikatori, F10, to‘g‘ri imzo, filiallar ro‘yxati va Win+1/2/3/4 tartibini tekshiring. Kelishilgan sinov qo‘ng‘iroqlari va xabarlarini faqat oluvchilarni tekshirgach bajaring. Yangilashda faqat Albert-V2.ahk ni almashtiring, settings.ini va activity_log.txt ni saqlang; keyin skriptni qayta oching.'),
 N('Avtomatik yuklanishni o‘chirish uchun Win+R -> shell:startup ni ochib, Albert.lnk ni o‘chiring. Yangi kompyuterda individual sozlashni qayta bajaring. Turli papkalardagi eski va yangi nusxalarni bir vaqtda ishlatmang.')
], '21 / STARTUP')

def flow(block):
    kind=block[0]
    if kind=='section':
        return [para(block[1],'h'),para(block[2])]
    if kind=='note':
        table=Table([[para(block[1],'note')]],colWidths=[W-96])
        table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),LIGHT),('BOX',(0,0),(-1,-1),0.5,LINE),
            ('LEFTPADDING',(0,0),(-1,-1),12),('RIGHTPADDING',(0,0),(-1,-1),12),
            ('TOPPADDING',(0,0),(-1,-1),11),('BOTTOMPADDING',(0,0),(-1,-1),11)]))
        return [Spacer(1,9),table,Spacer(1,6)]
    headers,rows=block[1:]
    data=[[para(x,'th') for x in headers]]+[[para(x,'cell') for x in row] for row in rows]
    table=Table(data,colWidths=[153,W-96-153],hAlign='LEFT')
    table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),NAVY),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,LIGHT]),
        ('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),10),('RIGHTPADDING',(0,0),(-1,-1),10),
        ('TOPPADDING',(0,0),(-1,-1),9),('BOTTOMPADDING',(0,0),(-1,-1),9),
        ('LINEBELOW',(0,-1),(-1,-1),0.5,LINE)]))
    return [table,Spacer(1,8)]

def frame(c,number,total,lang):
    c.setFillColor(NAVY); c.rect(0,H-9,W,9,fill=1,stroke=0)
    c.setFont('AB',9); c.drawString(48,H-36,'ALBERT / '+('РУКОВОДСТВО' if lang=='ru' else 'QO‘LLANMA'))
    c.setFillColor(MUTED); c.setFont('A',8); c.drawRightString(W-48,H-36,'25.09.2026 / '+lang.upper())
    c.setStrokeColor(LINE); c.line(48,44,W-48,44)
    c.setFont('A',8); c.drawString(48,29,'Albert-V2.ahk  |  SHA-256: '+DIGEST[:12])
    c.setFont('AB',9); c.drawRightString(W-48,29,f'{number:02d} / {total:02d}')

def draw_flows(c, items, y=H-70, bottom=62):
    for f in items:
        y-=f.getSpaceBefore()
        _,h=f.wrap(W-96,y-bottom)
        if y-h<bottom:
            raise RuntimeError(f'Page {c.getPageNumber()} overflow by {bottom-(y-h):.1f}: {getattr(f,"text",str(f))[:90]}')
        f.drawOn(c,48,y-h)
        y-=h+f.getSpaceAfter()
    return y

def make(lang):
    name='Albert_Release_Manual_'+lang.upper()+'.pdf'
    target=OUT/name
    total=len(PAGES)+2
    c=canvas.Canvas(str(target),pagesize=(W,H),pageCompression=1)
    c.setTitle('Albert | '+('Руководство пользователя' if lang=='ru' else 'Foydalanuvchi qo‘llanmasi'))
    c.setAuthor('Albert project')
    frame(c,1,total,lang)
    c.setFillColor(TEAL); c.roundRect(48,H-155,140,28,6,fill=1,stroke=0)
    c.setFillColor(colors.white); c.setFont('AB',10); c.drawString(60,H-145,'WINDOWS / AHK v2')
    c.setFillColor(NAVY); c.setFont('AB',60); c.drawString(44,H-241,'ALBERT')
    title='Руководство\nпользователя' if lang=='ru' else 'Foydalanuvchi\nqo‘llanmasi'
    draw_flows(c,[para(title,'title'),para('Переносимый релиз Albert-V2.ahk' if lang=='ru' else 'Albert-V2.ahk ko‘chiriladigan relizi','deck')],H-280)
    intro=('Все рабочие клавиши, режимы, настройки сотрудника, филиалы, статистика и установка на другом ПК.' if lang=='ru' else 'Barcha ish tugmalari, rejimlar, xodim sozlamalari, filiallar, statistika va boshqa kompyuterga o‘rnatish.')
    draw_flows(c,[para(intro),Spacer(1,16),*flow(N('Установка и первый запуск находятся в конце руководства. Описание сверено с передаваемым релизным кодом; известные ограничения указаны прямо.' if lang=='ru' else 'O‘rnatish va birinchi ishga tushirish qo‘llanma oxirida. Tavsif tarqatiladigan reliz kodi bilan solishtirilgan; mavjud cheklovlar ochiq ko‘rsatilgan.'))],H-415)
    c.setFillColor(MUTED); c.setFont('A',10)
    c.drawString(48,114,('Русская версия' if lang=='ru' else 'O‘zbekcha nashr - lotin yozuvi')+' / 25.09.2026')
    c.drawString(48,94,('Папка установки: ' if lang=='ru' else 'O‘rnatish papkasi: ')+r'C:\Albert')
    c.bookmarkPage('cover'); c.addOutlineEntry('ALBERT','cover',0)
    c.showPage()
    frame(c,2,total,lang)
    draw_flows(c,[para('Содержание' if lang=='ru' else 'Mundarija','title'),para('Найдите клавишу или задачу. Номер справа - страница PDF.' if lang=='ru' else 'Tugma yoki vazifani toping. O‘ngdagi raqam - PDF sahifasi.','deck')])
    y=H-145
    for i,p in enumerate(PAGES,3):
        c.setFillColor(INK); c.setFont('A',10)
        title=clean(p[lang]); c.drawString(48,y,title)
        c.setFont('AB',10); c.setFillColor(TEAL); c.drawRightString(W-48,y,str(i))
        c.linkRect('',f'p{i}',(48,y-4,W-48,y+12),relative=0,thickness=0)
        y-=25
    c.showPage()
    minimum=[]
    for i,p in enumerate(PAGES,3):
        frame(c,i,total,lang)
        c.bookmarkPage(f'p{i}'); c.addOutlineEntry(clean(p[lang]),f'p{i}',0)
        c.setFillColor(TEAL); c.setFont('AB',9); c.drawString(48,H-69,p['tag'])
        items=[para(p[lang],'title')]
        for block in p['br' if lang=='ru' else 'bu']:
            items+=flow(block)
        bottom=draw_flows(c,items,H-92)
        minimum.append(round(bottom,1))
        c.showPage()
    c.save()
    reader=PdfReader(target)
    assert len(reader.pages)==total and total>=15
    texts=[p.extract_text() or '' for p in reader.pages]
    assert all(len(t)>300 for t in texts)
    assert all('\ufffd' not in t and '\u25a0' not in t for t in texts)
    for key in ['F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12','End','Escape','Insert','Home','ScrollLock','PgUp','PgDn','PrintScreen','Launch_Media','Browser_Home','Volume_Mute','Volume_Up','Volume_Down','SC029','Pause']:
        assert key in '\n'.join(texts), key
    return {'file':str(target),'pages':total,'bytes':target.stat().st_size,'text_chars':sum(map(len,texts)),'lowest_content_y':min(minimum),'source_sha256':DIGEST}

if __name__=='__main__':
    result=[make('ru'),make('uz')]
    (ROOT/'tmp/pdfs/qa.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))
