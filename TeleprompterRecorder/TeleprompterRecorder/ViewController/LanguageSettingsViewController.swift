//
//  LanguageSettingsViewController.swift
//  TeleprompterRecorder
//

import UIKit

final class LanguageSettingsViewController: UITableViewController {

    private let languages = LanguageManager.shared.availableLanguages

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("language.title")
        applyDarkStyle()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LangCell")
        tableView.tableFooterView = UIView()
    }

    // MARK: - TableView

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        languages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LangCell", for: indexPath)
        let lang = languages[indexPath.row]
        cell.textLabel?.text = lang.localName
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .clear
        cell.tintColor = .systemCyan
        cell.accessoryType = lang.code == LanguageManager.shared.currentLanguage ? .checkmark : .none
        let sel = UIView()
        sel.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.12)
        cell.selectedBackgroundView = sel
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selected = languages[indexPath.row].code
        guard selected != LanguageManager.shared.currentLanguage else { return }
        LanguageManager.shared.currentLanguage = selected
        // Update title and checkmarks
        title = L("language.title")
        tableView.reloadData()
    }
}

// MARK: - Dark Style

private extension LanguageSettingsViewController {
    func applyDarkStyle() {
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        tableView.backgroundColor = UIColor(white: 0.06, alpha: 1)
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.09)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.10, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemCyan

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L("settings.close"), style: .plain,
            target: self, action: #selector(closeTapped))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
