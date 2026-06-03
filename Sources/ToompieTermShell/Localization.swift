import Combine
import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ru
    case zh

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .zh: return "中文"
        }
    }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .ru: return "🇷🇺"
        case .zh: return "🇨🇳"
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "appLanguage"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey), let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("ru") {
                language = .ru
            } else if preferred.hasPrefix("zh") {
                language = .zh
            } else {
                language = .en
            }
        }
    }

    func string(_ key: String) -> String {
        let value: String
        if let table = Self.tables[language], let found = table[key] {
            value = found
        } else if let fallback = Self.tables[.en]?[key] {
            value = fallback
        } else {
            value = key
        }
        if AppPreferences.shared.textCase == .lower {
            return value.lowercased()
        }
        return value
    }

    func callAsFunction(_ key: String) -> String {
        string(key)
    }
}

extension LocalizationManager {
    static let tables: [AppLanguage: [String: String]] = [
        .en: en,
        .ru: ru,
        .zh: zh
    ]

    private static let en: [String: String] = [
        "tab.projects": "Projects",
        "tab.ssh": "SSH",
        "tab.paths": "Paths",
        "tab.commands": "Commands",
        "tab.settings": "Settings",

        "common.add": "Add",
        "common.edit": "Edit",
        "common.delete": "Delete",
        "common.save": "Save",
        "common.cancel": "Cancel",
        "common.copy": "Copy",
        "common.run": "Run",
        "common.connect": "Connect",
        "common.open": "Open",
        "common.name": "Name",
        "common.empty": "Nothing here yet",
        "common.choose": "Choose",
        "common.newTab": "New tab",
        "common.closeTab": "Close tab",

        "terminal.panel": "Panel",
        "terminal.usePanels": "Use %@ panel(s)",
        "terminal.dropHint": "Drop a file to paste its path",
        "terminal.rename": "Rename tab",

        "settings.title": "Settings",
        "settings.appearance": "Appearance",
        "settings.language": "Language",
        "settings.font": "Font",
        "settings.fontSize": "Font size",
        "settings.fontLibrary": "Google Fonts library",
        "settings.background": "Background",
        "settings.theme": "Color theme",
        "settings.opacity": "Terminal opacity",
        "settings.cursor": "Cursor style",
        "settings.foreground": "Text color",
        "settings.bgColor": "Background color",
        "settings.about": "About",
        "settings.repo": "GitHub repository",
        "settings.download": "Download",
        "settings.downloaded": "Downloaded",
        "settings.downloading": "Downloading…",
        "settings.offlineReady": "Available offline",
        "settings.systemFont": "System monospaced",
        "settings.bgImage": "Background image",
        "settings.chooseImage": "Choose image…",
        "settings.clearImage": "Clear image",
        "settings.confirmDangerous": "Confirm dangerous commands",
        "settings.resetFonts": "Remove downloaded fonts",

        "cursor.block": "Block",
        "cursor.bar": "Bar",
        "cursor.underline": "Underline",

        "bg.solid": "Solid",
        "bg.gradient": "Gradient",
        "bg.image": "Image",

        "projects.servers": "Servers",
        "projects.ssh": "SSH",
        "projects.logs": "Logs",
        "projects.docker": "Docker",
        "projects.deploy": "Deploy",
        "projects.notes": "Notes",

        "servers.add": "Add server",
        "servers.host": "Host",
        "servers.port": "Port",
        "servers.user": "User",
        "servers.tags": "Tags",
        "servers.note": "Note",
        "servers.ping": "Ping",
        "servers.ssh": "SSH",

        "logs.add": "Add log source",
        "logs.command": "Command",
        "logs.follow": "Follow",
        "logs.group": "Group",

        "docker.add": "Add docker project",
        "docker.dir": "Compose directory",
        "docker.ps": "Containers",
        "docker.images": "Images",
        "docker.up": "Up",
        "docker.down": "Down",
        "docker.logs": "Logs",
        "docker.prune": "Prune",

        "deploy.add": "Add deploy target",
        "deploy.command": "Command",
        "deploy.dir": "Working directory",
        "deploy.description": "Description",
        "deploy.run": "Deploy",

        "notes.add": "Add note",
        "notes.title": "Title",
        "notes.body": "Content",
        "notes.updated": "Updated",

        "ssh.add": "Add SSH shortcut",
        "ssh.auth": "Auth type",
        "ssh.key": "Private key path",
        "ssh.password": "Password",
        "ssh.remember": "Store password in Keychain",
        "ssh.startupDir": "Startup directory",
        "ssh.startupCmd": "Startup command",
        "ssh.newTab": "Open in new tab",

        "paths.pin": "Pin directory",
        "paths.cd": "CD",
        "paths.absolute": "Absolute path",

        "commands.add": "Add command shortcut",
        "commands.command": "Command",
        "commands.dir": "Working directory",
        "commands.description": "Description",
        "commands.tags": "Tags / Group",

        "projects.config": "Config",
        "projects.scope": "Scope",
        "projects.add": "Add project",
        "projects.rename": "Rename project",
        "projects.deleteConfirm": "Delete project and its items?",
        "scope.global": "Global",
        "scope.hint": "Items below belong to the selected scope",

        "view.simple": "Simple",
        "view.detailed": "Detailed",
        "common.runIn": "Run in",
        "common.focused": "Focused",

        "settings.aliased": "Pixelated text (no antialiasing)",

        "config.rc": "Shell config files",
        "config.env": "Project files (.env, …)",
        "config.add": "Add file",
        "config.path": "Path",
        "config.openTerminal": "Edit in terminal",
        "config.missing": "File not found",
        "config.create": "Create",

        "tab.locations": "Locations",
        "tab.config": "Config",
        "tab.tags": "Tags",

        "bg.native": "macOS",
        "case.default": "Default",
        "case.large": "Large text",
        "case.lower": "lowercase",

        "settings.textCase": "Interface text",
        "settings.accent": "Accent color",
        "settings.gif": "Dashboard GIF",
        "settings.chooseGif": "Choose GIF…",
        "settings.clearGif": "Remove GIF",

        "tags.title": "Tags",
        "tags.add": "Add tag",
        "tags.color": "Color",
        "tags.untagged": "Untagged",
        "tags.items": "items",
        "search.placeholder": "Search…",
        "filter.all": "All",

        "config.defaults": "Defaults",
        "config.keyDir": "SSH keys directory",
        "config.user": "Default user",
        "config.port": "Default port",
        "config.editor": "Default editor",
        "config.workdir": "Default working directory",

        "ssh.icon": "Icon",
        "ssh.files": "Files",
        "ftp.openRemote": "Edit remote file",
        "ftp.path": "Remote path",
        "ftp.fetching": "Fetching…",
        "ftp.uploading": "Uploading…",
        "editor.openLocal": "Edit a file",

        "locations.add": "Pin location",

        "settings.weather": "Weather effect",
        "weather.off": "Off",
        "weather.snow": "Snow",
        "weather.rain": "Rain",

        "gif.library": "GIF library",
        "gif.addFile": "Add from file",
        "gif.addUrl": "Add from URL",
        "gif.url": "https://…/animation.gif",
        "gif.size": "Size",
        "gif.opacity": "Opacity",
        "gif.radius": "Corner radius",
        "gif.border": "Show border",
        "gif.none": "No GIF library yet",
        "gif.fit": "Fit (no crop)",
        "gif.box": "Show box",
        "gif.boxOpacity": "Box opacity",
        "gif.innerScale": "Zoom",
        "gif.rotation": "Rotation",
        "gif.flip": "Mirror",
        "gif.editable": "Move / resize on canvas",
        "gif.resetPos": "Reset position",
        "gif.editHint": "Drag the GIF on the window; use the corner to resize",

        "settings.bgAdjust": "Image adjustments",
        "settings.bgInvert": "Invert colors",
        "settings.bgGrayscale": "Grayscale",
        "settings.bgBlur": "Blur",
        "settings.bgBrightness": "Brightness",
        "settings.bgDim": "Dim"
    ]

    private static let ru: [String: String] = [
        "tab.projects": "Проекты",
        "tab.ssh": "SSH",
        "tab.paths": "Пути",
        "tab.commands": "Команды",
        "tab.settings": "Настройки",

        "common.add": "Добавить",
        "common.edit": "Изменить",
        "common.delete": "Удалить",
        "common.save": "Сохранить",
        "common.cancel": "Отмена",
        "common.copy": "Копировать",
        "common.run": "Запустить",
        "common.connect": "Подключиться",
        "common.open": "Открыть",
        "common.name": "Название",
        "common.empty": "Здесь пока пусто",
        "common.choose": "Выбрать",
        "common.newTab": "Новая вкладка",
        "common.closeTab": "Закрыть вкладку",

        "terminal.panel": "Панель",
        "terminal.usePanels": "Использовать панелей: %@",
        "terminal.dropHint": "Перетащите файл, чтобы вставить путь",
        "terminal.rename": "Переименовать вкладку",

        "settings.title": "Настройки",
        "settings.appearance": "Внешний вид",
        "settings.language": "Язык",
        "settings.font": "Шрифт",
        "settings.fontSize": "Размер шрифта",
        "settings.fontLibrary": "Библиотека Google Fonts",
        "settings.background": "Фон",
        "settings.theme": "Цветовая тема",
        "settings.opacity": "Прозрачность терминала",
        "settings.cursor": "Стиль курсора",
        "settings.foreground": "Цвет текста",
        "settings.bgColor": "Цвет фона",
        "settings.about": "О программе",
        "settings.repo": "Репозиторий GitHub",
        "settings.download": "Скачать",
        "settings.downloaded": "Скачан",
        "settings.downloading": "Загрузка…",
        "settings.offlineReady": "Доступен оффлайн",
        "settings.systemFont": "Системный моноширинный",
        "settings.bgImage": "Фоновое изображение",
        "settings.chooseImage": "Выбрать изображение…",
        "settings.clearImage": "Убрать изображение",
        "settings.confirmDangerous": "Подтверждать опасные команды",
        "settings.resetFonts": "Удалить скачанные шрифты",

        "cursor.block": "Блок",
        "cursor.bar": "Линия",
        "cursor.underline": "Подчёркивание",

        "bg.solid": "Цвет",
        "bg.gradient": "Градиент",
        "bg.image": "Изображение",

        "projects.servers": "Серверы",
        "projects.ssh": "SSH",
        "projects.logs": "Логи",
        "projects.docker": "Docker",
        "projects.deploy": "Деплой",
        "projects.notes": "Заметки",

        "servers.add": "Добавить сервер",
        "servers.host": "Хост",
        "servers.port": "Порт",
        "servers.user": "Пользователь",
        "servers.tags": "Теги",
        "servers.note": "Заметка",
        "servers.ping": "Ping",
        "servers.ssh": "SSH",

        "logs.add": "Добавить источник логов",
        "logs.command": "Команда",
        "logs.follow": "Следить",
        "logs.group": "Группа",

        "docker.add": "Добавить проект Docker",
        "docker.dir": "Каталог compose",
        "docker.ps": "Контейнеры",
        "docker.images": "Образы",
        "docker.up": "Запуск",
        "docker.down": "Остановка",
        "docker.logs": "Логи",
        "docker.prune": "Очистка",

        "deploy.add": "Добавить цель деплоя",
        "deploy.command": "Команда",
        "deploy.dir": "Рабочий каталог",
        "deploy.description": "Описание",
        "deploy.run": "Деплой",

        "notes.add": "Добавить заметку",
        "notes.title": "Заголовок",
        "notes.body": "Содержимое",
        "notes.updated": "Обновлено",

        "ssh.add": "Добавить SSH-подключение",
        "ssh.auth": "Тип авторизации",
        "ssh.key": "Путь к приватному ключу",
        "ssh.password": "Пароль",
        "ssh.remember": "Сохранить пароль в Связке ключей",
        "ssh.startupDir": "Стартовый каталог",
        "ssh.startupCmd": "Стартовая команда",
        "ssh.newTab": "Открыть в новой вкладке",

        "paths.pin": "Закрепить каталог",
        "paths.cd": "Перейти",
        "paths.absolute": "Абсолютный путь",

        "commands.add": "Добавить команду",
        "commands.command": "Команда",
        "commands.dir": "Рабочий каталог",
        "commands.description": "Описание",
        "commands.tags": "Теги / Группа",

        "projects.config": "Конфиги",
        "projects.scope": "Область",
        "projects.add": "Добавить проект",
        "projects.rename": "Переименовать проект",
        "projects.deleteConfirm": "Удалить проект и его элементы?",
        "scope.global": "Глобально",
        "scope.hint": "Элементы ниже относятся к выбранной области",

        "view.simple": "Просто",
        "view.detailed": "Подробно",
        "common.runIn": "Выполнить в",
        "common.focused": "Активной",

        "settings.aliased": "Пиксельный текст (без сглаживания)",

        "config.rc": "Файлы конфигурации оболочки",
        "config.env": "Файлы проекта (.env, …)",
        "config.add": "Добавить файл",
        "config.path": "Путь",
        "config.openTerminal": "Открыть в терминале",
        "config.missing": "Файл не найден",
        "config.create": "Создать",

        "tab.locations": "Локации",
        "tab.config": "Конфиг",
        "tab.tags": "Теги",

        "bg.native": "macOS",
        "case.default": "Обычный",
        "case.large": "Крупный текст",
        "case.lower": "строчные",

        "settings.textCase": "Текст интерфейса",
        "settings.accent": "Акцентный цвет",
        "settings.gif": "GIF на панели",
        "settings.chooseGif": "Выбрать GIF…",
        "settings.clearGif": "Убрать GIF",

        "tags.title": "Теги",
        "tags.add": "Добавить тег",
        "tags.color": "Цвет",
        "tags.untagged": "Без тегов",
        "tags.items": "элементов",
        "search.placeholder": "Поиск…",
        "filter.all": "Все",

        "config.defaults": "Значения по умолчанию",
        "config.keyDir": "Каталог SSH-ключей",
        "config.user": "Пользователь по умолчанию",
        "config.port": "Порт по умолчанию",
        "config.editor": "Редактор по умолчанию",
        "config.workdir": "Рабочий каталог по умолчанию",

        "ssh.icon": "Иконка",
        "ssh.files": "Файлы",
        "ftp.openRemote": "Редактировать удалённый файл",
        "ftp.path": "Удалённый путь",
        "ftp.fetching": "Загрузка…",
        "ftp.uploading": "Отправка…",
        "editor.openLocal": "Редактировать файл",

        "locations.add": "Закрепить локацию",

        "settings.weather": "Эффект погоды",
        "weather.off": "Выкл",
        "weather.snow": "Снег",
        "weather.rain": "Дождь",

        "gif.library": "Библиотека GIF",
        "gif.addFile": "Добавить из файла",
        "gif.addUrl": "Добавить по ссылке",
        "gif.url": "https://…/animation.gif",
        "gif.size": "Размер",
        "gif.opacity": "Прозрачность",
        "gif.radius": "Скругление углов",
        "gif.border": "Показывать рамку",
        "gif.none": "Библиотека GIF пуста",
        "gif.fit": "Вписать (без обрезки)",
        "gif.box": "Показывать контейнер",
        "gif.boxOpacity": "Прозрачность контейнера",
        "gif.innerScale": "Масштаб",
        "gif.rotation": "Поворот",
        "gif.flip": "Зеркало",
        "gif.editable": "Двигать / менять размер на окне",
        "gif.resetPos": "Сбросить позицию",
        "gif.editHint": "Перетаскивай GIF по окну; угол — изменение размера",

        "settings.bgAdjust": "Коррекция изображения",
        "settings.bgInvert": "Инверсия цветов",
        "settings.bgGrayscale": "Чёрно-белый",
        "settings.bgBlur": "Размытие",
        "settings.bgBrightness": "Яркость",
        "settings.bgDim": "Затемнение"
    ]

    private static let zh: [String: String] = [
        "tab.projects": "项目",
        "tab.ssh": "SSH",
        "tab.paths": "路径",
        "tab.commands": "命令",
        "tab.settings": "设置",

        "common.add": "添加",
        "common.edit": "编辑",
        "common.delete": "删除",
        "common.save": "保存",
        "common.cancel": "取消",
        "common.copy": "复制",
        "common.run": "运行",
        "common.connect": "连接",
        "common.open": "打开",
        "common.name": "名称",
        "common.empty": "这里还没有内容",
        "common.choose": "选择",
        "common.newTab": "新标签页",
        "common.closeTab": "关闭标签页",

        "terminal.panel": "面板",
        "terminal.usePanels": "使用 %@ 个面板",
        "terminal.dropHint": "拖入文件以粘贴其路径",
        "terminal.rename": "重命名标签页",

        "settings.title": "设置",
        "settings.appearance": "外观",
        "settings.language": "语言",
        "settings.font": "字体",
        "settings.fontSize": "字号",
        "settings.fontLibrary": "Google 字体库",
        "settings.background": "背景",
        "settings.theme": "配色主题",
        "settings.opacity": "终端透明度",
        "settings.cursor": "光标样式",
        "settings.foreground": "文字颜色",
        "settings.bgColor": "背景颜色",
        "settings.about": "关于",
        "settings.repo": "GitHub 仓库",
        "settings.download": "下载",
        "settings.downloaded": "已下载",
        "settings.downloading": "下载中…",
        "settings.offlineReady": "可离线使用",
        "settings.systemFont": "系统等宽字体",
        "settings.bgImage": "背景图片",
        "settings.chooseImage": "选择图片…",
        "settings.clearImage": "清除图片",
        "settings.confirmDangerous": "确认危险命令",
        "settings.resetFonts": "删除已下载字体",

        "cursor.block": "方块",
        "cursor.bar": "竖线",
        "cursor.underline": "下划线",

        "bg.solid": "纯色",
        "bg.gradient": "渐变",
        "bg.image": "图片",

        "projects.servers": "服务器",
        "projects.ssh": "SSH",
        "projects.logs": "日志",
        "projects.docker": "Docker",
        "projects.deploy": "部署",
        "projects.notes": "笔记",

        "servers.add": "添加服务器",
        "servers.host": "主机",
        "servers.port": "端口",
        "servers.user": "用户",
        "servers.tags": "标签",
        "servers.note": "备注",
        "servers.ping": "Ping",
        "servers.ssh": "SSH",

        "logs.add": "添加日志源",
        "logs.command": "命令",
        "logs.follow": "跟踪",
        "logs.group": "分组",

        "docker.add": "添加 Docker 项目",
        "docker.dir": "Compose 目录",
        "docker.ps": "容器",
        "docker.images": "镜像",
        "docker.up": "启动",
        "docker.down": "停止",
        "docker.logs": "日志",
        "docker.prune": "清理",

        "deploy.add": "添加部署目标",
        "deploy.command": "命令",
        "deploy.dir": "工作目录",
        "deploy.description": "描述",
        "deploy.run": "部署",

        "notes.add": "添加笔记",
        "notes.title": "标题",
        "notes.body": "内容",
        "notes.updated": "更新于",

        "ssh.add": "添加 SSH 快捷方式",
        "ssh.auth": "认证方式",
        "ssh.key": "私钥路径",
        "ssh.password": "密码",
        "ssh.remember": "在钥匙串中保存密码",
        "ssh.startupDir": "启动目录",
        "ssh.startupCmd": "启动命令",
        "ssh.newTab": "在新标签页打开",

        "paths.pin": "固定目录",
        "paths.cd": "进入",
        "paths.absolute": "绝对路径",

        "commands.add": "添加命令快捷方式",
        "commands.command": "命令",
        "commands.dir": "工作目录",
        "commands.description": "描述",
        "commands.tags": "标签 / 分组",

        "projects.config": "配置",
        "projects.scope": "范围",
        "projects.add": "添加项目",
        "projects.rename": "重命名项目",
        "projects.deleteConfirm": "删除项目及其内容？",
        "scope.global": "全局",
        "scope.hint": "下列内容属于所选范围",

        "view.simple": "简洁",
        "view.detailed": "详细",
        "common.runIn": "运行于",
        "common.focused": "当前",

        "settings.aliased": "像素化文字（关闭抗锯齿）",

        "config.rc": "Shell 配置文件",
        "config.env": "项目文件 (.env, …)",
        "config.add": "添加文件",
        "config.path": "路径",
        "config.openTerminal": "在终端中编辑",
        "config.missing": "未找到文件",
        "config.create": "创建",

        "tab.locations": "位置",
        "tab.config": "配置",
        "tab.tags": "标签",

        "bg.native": "macOS",
        "case.default": "默认",
        "case.large": "大字体",
        "case.lower": "小写",

        "settings.textCase": "界面文字",
        "settings.accent": "强调色",
        "settings.gif": "面板 GIF",
        "settings.chooseGif": "选择 GIF…",
        "settings.clearGif": "移除 GIF",

        "tags.title": "标签",
        "tags.add": "添加标签",
        "tags.color": "颜色",
        "tags.untagged": "无标签",
        "tags.items": "项",
        "search.placeholder": "搜索…",
        "filter.all": "全部",

        "config.defaults": "默认值",
        "config.keyDir": "SSH 密钥目录",
        "config.user": "默认用户",
        "config.port": "默认端口",
        "config.editor": "默认编辑器",
        "config.workdir": "默认工作目录",

        "ssh.icon": "图标",
        "ssh.files": "文件",
        "ftp.openRemote": "编辑远程文件",
        "ftp.path": "远程路径",
        "ftp.fetching": "获取中…",
        "ftp.uploading": "上传中…",
        "editor.openLocal": "编辑文件",

        "locations.add": "固定位置",

        "settings.weather": "天气效果",
        "weather.off": "关闭",
        "weather.snow": "雪",
        "weather.rain": "雨",

        "gif.library": "GIF 库",
        "gif.addFile": "从文件添加",
        "gif.addUrl": "从链接添加",
        "gif.url": "https://…/animation.gif",
        "gif.size": "大小",
        "gif.opacity": "不透明度",
        "gif.radius": "圆角",
        "gif.border": "显示边框",
        "gif.none": "GIF 库为空",
        "gif.fit": "适应（不裁剪）",
        "gif.box": "显示容器",
        "gif.boxOpacity": "容器不透明度",
        "gif.innerScale": "缩放",
        "gif.rotation": "旋转",
        "gif.flip": "镜像",
        "gif.editable": "在窗口上移动 / 调整大小",
        "gif.resetPos": "重置位置",
        "gif.editHint": "在窗口上拖动 GIF；用角落调整大小",

        "settings.bgAdjust": "图像调整",
        "settings.bgInvert": "反色",
        "settings.bgGrayscale": "灰度",
        "settings.bgBlur": "模糊",
        "settings.bgBrightness": "亮度",
        "settings.bgDim": "变暗"
    ]
}
