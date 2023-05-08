//
//  DetailVC.swift
//  Demo
//
//  Created by apple on 09/11/22.
//

import UIKit

class DetailVC: UIViewController {
var typeService = String()
    @IBOutlet weak var lblDescription: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        startSearch()
    }
    func startSearch() {
        
       print(typeService)
        Bonjour.sharedInstance.services = []
        Bonjour.sharedInstance.findService(typeService, domain: Bonjour.LocalDomain) { (services) in
            print(services)
            var s = ""
            for service in services{
                s = s + "Name: \(service.name)\nDomain: \(service.domain)\nPort: \(service.port)\n"
            }
            self.lblDescription.text = s
            // Do something with your services!
            // services will be an empty array if nothing was found
        }
    }
}




























//
//  ViewController.swift
//  Demo
//
//  Created by apple on 09/11/22.
//

import UIKit

class DomainListVC: UIViewController {
    
    @IBOutlet weak var tblVwDomains: UITableView!
    private lazy var serviceBrowser = NetServiceBrowser()

    override func viewDidLoad() {
        super.viewDidLoad()
        startSearch()
        
    }
   
    var domainsList = [String](){
        didSet{
            self.tblVwDomains.reloadData()
        }
    }
    func startSearch() {
        // This will find all HTTP servers - Check out Bonjour.Services for common services
        Bonjour.sharedInstance.findDomains { (domains) in
            for item in domains{
                self.domainsList.append(item)
            }
        }
    }
}


extension DomainListVC: UITableViewDelegate, UITableViewDataSource {
func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.domainsList.count
}

func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") else{
        return UITableViewCell()
    }

    guard self.domainsList.count > 0 else{
        return cell
    }
    let service = self.domainsList[indexPath.row]
    cell.textLabel?.text = "\(service)"
    return cell
}
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "ServiceTypeListVC") as! ServiceTypeListVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
