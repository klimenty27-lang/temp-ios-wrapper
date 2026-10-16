import UIKit

final class TempSettingsViewController: UIViewController {
    var selectedMode: String = "biometric"
    var onSelect: ((String) -> Void)?
    var webVersion = "не определена"
    var savedLogin = ""
    var rememberLogin = true
    var onRememberLogin: ((Bool) -> Void)?
    var onForgetLogin: (() -> Void)?
    private let orange = UIColor(red: 1, green: 0.54, blue: 0.13, alpha: 1)
    private let navy = UIColor(red: 0.025, green: 0.09, blue: 0.17, alpha: 1)
    private let stack = UIStackView()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Настройки ТЕМП"
        view.backgroundColor = navy
        navigationController?.navigationBar.tintColor = orange
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(close))
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        refresh()
    }
    @objc private func close() { dismiss(animated: true) }
    private func text(_ value: String, size: CGFloat, color: UIColor = .white) -> UILabel {
        let label = UILabel()
        label.text = value
        label.textColor = color
        label.font = .systemFont(ofSize: size)
        label.numberOfLines = 0
        return label
    }
    private func card(_ title: String, description: String) -> UIStackView {
        let group = UIStackView()
        group.axis = .vertical
        group.spacing = 12
        group.layoutMargins = UIEdgeInsets(top: 17, left: 17, bottom: 17, right: 17)
        group.isLayoutMarginsRelativeArrangement = true
        group.backgroundColor = UIColor(red: 0.05, green: 0.16, blue: 0.28, alpha: 1)
        group.layer.cornerRadius = 16
        group.layer.borderWidth = 1
        group.layer.borderColor = UIColor(red: 0.17, green: 0.33, blue: 0.48, alpha: 1).cgColor
        group.addArrangedSubview(text(title, size: 18))
        group.addArrangedSubview(text(description, size: 13, color: .lightGray))
        stack.addArrangedSubview(group)
        return group
    }
    private func addOption(_ title: String, key: String, group: UIStackView) {
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.titleLabel?.numberOfLines = 0
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.setTitle((selectedMode == key ? "✓  " : "○  ") + title, for: .normal)
        button.setTitleColor(selectedMode == key ? orange : .white, for: .normal)
        button.addAction(UIAction { [weak self] _ in
            self?.selectedMode = key
            self?.onSelect?(key)
            self?.refresh()
        }, for: .touchUpInside)
        group.addArrangedSubview(button)
    }
    private func refresh() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let access = card("Вход и безопасность", description: "Защита доступа к приложению на этом iPhone")
        addOption("Face ID или код-пароль устройства", key: "biometric", group: access)
        addOption("Без повторной проверки", key: "none", group: access)
        access.addArrangedSubview(text("Пароль аккаунта ТЕМП по-прежнему проверяется сервером.", size: 12, color: .lightGray))
        let login = card("Сохранённый логин", description: savedLogin.isEmpty ? "Сохранённого логина пока нет." : savedLogin)
        let toggle = UIButton(type: .system)
        toggle.setTitle((rememberLogin ? "✓ " : "○ ") + "Запоминать логин", for: .normal)
        toggle.contentHorizontalAlignment = .left
        toggle.setTitleColor(orange, for: .normal)
        toggle.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        toggle.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.rememberLogin.toggle()
            if !self.rememberLogin { self.savedLogin = "" }
            self.onRememberLogin?(self.rememberLogin)
            self.refresh()
        }, for: .touchUpInside)
        login.addArrangedSubview(toggle)
        let forget = UIButton(type: .system)
        forget.setTitle("Забыть сохранённый логин", for: .normal)
        forget.contentHorizontalAlignment = .left
        forget.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        forget.setTitleColor(orange, for: .normal)
        forget.addAction(UIAction { [weak self] _ in
            self?.onForgetLogin?()
            self?.savedLogin = ""
            self?.refresh()
        }, for: .touchUpInside)
        login.addArrangedSubview(forget)
        login.addArrangedSubview(text("Пароль ТЕМП здесь не хранится. Для его заполнения используйте сохранённую запись в системных «Паролях». При нажатии «Выйти» вход в аккаунт завершается.", size: 13, color: .lightGray))
        _ = card("Мой профиль", description: "ФИО, должность и учётная запись — в личном кабинете ТЕМП.")
        _ = card("Уведомления", description: "Push пока не подключены. Расписание напоминаний 21:00–22:00 остаётся согласованным, но этот пакет не включает серверную отправку.")
        let nativeVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        _ = card("О приложении", description: "Оболочка iOS: " + nativeVersion + " (" + build + ")\nВеб-версия ТЕМП: " + webVersion)

    }
}
