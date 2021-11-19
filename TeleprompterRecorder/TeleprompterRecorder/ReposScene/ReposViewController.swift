//
//  ViewController.swift
//
//  Created by YanQi on 2021/11/19.
//

import UIKit
import RxSwift
import RxCocoa

class ReposViewController: UIViewController {
    let viewModel = ReposViewModel(dependencies: ReposViewModel.Dependencies(networking: NetworkingApi()))
    
    private let tableView = UITableView()
    let searchController = UISearchController(searchResultsController: nil)

    private let searchTextField = UITextField()

    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        definesPresentationContext = true

        searchController.searchResultsUpdater = nil
        searchController.hidesNavigationBarDuringPresentation = false
        tableView.tableHeaderView = searchController.searchBar
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        bindViewModel()
    }
    
    private func bindViewModel() {
        let input = ReposViewModel.Input(ready: rx.viewWillAppear.asDriver(),
                                            selectedIndex: tableView.rx.itemSelected.asDriver(),
                                            searchText: searchController.searchBar.rx.text.orEmpty.asDriver())

        let output = viewModel.transform(input: input)

        output.repos
            .drive(tableView.rx.items(cellIdentifier: "Cell", cellType: UITableViewCell.self)) { (row, element, cell) in
                cell.textLabel?.text = element.name
            }
            .disposed(by: disposeBag)
        
        output.loading
            .drive(UIApplication.shared.rx.isNetworkActivityIndicatorVisible)
            .disposed(by: disposeBag)
        
        output.selectedRepoId
            .drive(onNext: { [weak self] repoId in
                guard let strongSelf = self else { return }
                let alertController = UIAlertController(title: "\(repoId)", message: nil, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                strongSelf.present(alertController, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
}
