//
//  SandArtViewController.swift
//  Sandart
//
//  Created by Joshua on 2018. 3. 24..
//  Copyright © 2018년 Joshua. All rights reserved.
//

import UIKit
import StoreKit
import Alamofire
import AVFoundation
import AVKit


class SandArtViewController: UIViewController,UITableViewDelegate, UITableViewDataSource,SKPaymentTransactionObserver,SKProductsRequestDelegate {
    
    @IBOutlet var tableView: UITableView!
    var table:SandartEntryTable?
    var products:Array<SKProduct?>?
    var playerView:AVPlayerViewController?
    var requestDic:Dictionary<String,Alamofire.Request> = Dictionary<String,Alamofire.Request>()
    var downloadProgress:Dictionary<String,Float> = Dictionary<String,Float>()
    var downloadingPath = Array<IndexPath>()
    let SandArtLanguages = ["Korean","English","Chinese","ChineseTraditional","Japanese", "Russian", "French", "Spanish", "Hindi","Mongolia", "Polish", "Turkish", "Nepali", "Indonesia","Thai", "Cambodian", "Filipino"]
    let manager = Alamofire.SessionManager(configuration: URLSessionConfiguration.background(withIdentifier: "org.kccc.P4U1.background"))
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        tableView.dataSource = self
        tableView.delegate = self
        
        let tabbarHeight = self.tabBarController!.tabBar.frame.size.height
        self.tableView.contentInset = UIEdgeInsetsMake(0,0,tabbarHeight,0)
        
        if(table == nil)
        {
            table = SandartEntryTable(With: SandArtLanguages)
            self.validateProductIdentifiers(productIdentifiers: SandArtLanguages)
        }
        for identifier in SandArtLanguages{
            downloadProgress[identifier] = 0.0
        }
    }
    
    func getScreenFrameForCurrentOrientation() -> CGRect{
        return self.getScreenFrameForOrientation(orientation: UIApplication.shared.statusBarOrientation)
    }
    
    func getScreenFrameForOrientation(orientation:UIInterfaceOrientation)->CGRect{
        let screen = UIScreen.main
        var fullScreenRect = screen.bounds
        let statusBarHidden = UIApplication.shared.isStatusBarHidden
        
        if orientation == UIInterfaceOrientation.landscapeRight || orientation == UIInterfaceOrientation.landscapeLeft{
            var temp = CGRect.zero
            temp.size.width = fullScreenRect.size.height
            temp.size.height = fullScreenRect.size.width
            fullScreenRect = temp
        }
        if !statusBarHidden{
            let statusBarSize = UIApplication.shared.statusBarFrame.size
            let statusBarHeight = Swift.min(statusBarSize.width, statusBarSize.height)
            fullScreenRect.size.height -= CGFloat(statusBarHeight)
        }
        
        return fullScreenRect
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - event handlers
    
    @IBAction func purchase(_ sender: Any) {
        let priceButton = sender as! UIButton
        let button = priceButton.superview?.viewWithTag(2) as! UIButton
        let langKey = button.title(for: UIControlState.application)!.trimmingCharacters(in: CharacterSet.init(charactersIn: " "))
        priceButton.isHidden = true
        
        let product = self.productForKey(langKey: langKey)
        self.paymentRequest(product: product)
    }
    
    @objc @IBAction func download(_ sender: Any) {
        let button = sender as! UIButton
        let langKey = button.title(for: UIControlState.application)
        
        self.downloadWithLangKey(langkey: langKey!)
    }
    
    func downloadWithLangKey(langkey:String){
        let entry = table!.entryWithLangKey(langkey)
        let indexPath = IndexPath.init(row: (table?.indexForLangKey(langkey))!, section: 1)
        if entry?.Status == MovieStatus.NotDownloaded{
            let targetPath = (Bundle.main.object(forInfoDictionaryKey: "Download Paths") as! NSDictionary).object(forKey: langkey) as! String
            let url = URL.init(string: targetPath)//download url
            //downloading with alamofire
            let destination:DownloadRequest.DownloadFileDestination = { _, _ in
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsURL.appendingPathComponent("SandArt/" + langkey + ".mp4")
                
                return (fileURL,[.removePreviousFile, .createIntermediateDirectories])
            }
            
            self.update(indexPath: indexPath, withStatus: MovieStatus.Downloading)
            downloadingPath.append(indexPath)
            let request = manager.download(url!,method: .get, to: destination)
                .downloadProgress{progress in
                        self.downloadProgress[langkey] = Float(progress.fractionCompleted)
                    
                }
                .responseData{
                    response in
                    
                    if response.result.isFailure{
                        if response.error!.localizedDescription == "cancelled"{ // user canceled, ignore
                            /*let title = "Download_Cancelled"
                            let av = UIAlertController.init(title: NSLocalizedString(title, comment: title), message: NSLocalizedString("", comment: ""), preferredStyle:.alert)
                            let cancel = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
                            av.addAction(cancel)
                            self.present(av, animated: true, completion: nil)*/
                        }
                        else{
                            let title = "Download_Error"
                            let message = "Try again"
                            let av = UIAlertController.init(title: NSLocalizedString(title, comment: title), message: NSLocalizedString(message, comment: message), preferredStyle:.alert)
                            let cancel = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
                            av.addAction(cancel)
                            self.present(av, animated: true, completion: nil)
                        }
                        self.update(indexPath: indexPath, withStatus: MovieStatus.NotDownloaded)
                    }
                    else{
                        self.addSkipBackupAttributeToItemAtURL(URL: response.destinationURL!)
                        self.update(indexPath: indexPath, withStatus: MovieStatus.Downloaded)
                    }
                    self.requestDic.removeValue(forKey: langkey)
                    self.downloadingPath.remove(at: self.downloadingPath.index(of: indexPath)!)
            }
            requestDic[langkey] = request
            Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updatePeriodically(timer:)), userInfo: nil, repeats: true)
            request.resume()
        }
    }
    
    func addSkipBackupAttributeToItemAtURL(URL:URL){
        
        assert(FileManager.default.fileExists(atPath: URL.path))
        
        var URL = URL
        
        do{
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try URL.setResourceValues(resourceValues)
        }
        catch {
            NSLog("Error execluding %@ from backup", URL.lastPathComponent)
        }
}
    @objc @IBAction func cancelDownloading(_ sender:Any){
        let button = sender as! UIButton
        let langKey = button.title(for: UIControlState.application)
        let indexPath = IndexPath.init(row: (table?.indexForLangKey(langKey!))!, section: 1)
        let download = requestDic[langKey!]
        
        if download != nil{
            download!.cancel()
        }
        
        self.update(indexPath: indexPath, withStatus: MovieStatus.NotDownloaded)
    }
    
    @objc @IBAction func play(_ sender:Any){
        let entry = self.entryForSender(sender)
        if(entry!.Status == MovieStatus.Downloaded){
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsURL.appendingPathComponent("SandArt/" + entry!.LangKey + ".mp4")
            let player = AVPlayer(url: url)
            playerView = AVPlayerViewController()
            playerView!.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
            playerView!.player = player
           NotificationCenter.default.addObserver(self, selector: #selector(moviePlayerPlaybackDidFinish(notification:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: playerView!.player?.currentItem)
            playerView!.view.frame = self.view.frame
            self.present(playerView!, animated: true){
                self.playerView!.player?.play()
            }
        }
        
    }
    //MARK: - event helpers
    @objc func moviePlayerPlaybackDidFinish(notification:Notification){
        playerView?.dismiss(animated: true, completion: nil)
        
    }
    
    func entryForSender(_ sender:Any)->SandartEntry?{
        let button = sender as! UIButton
        let langkey = button.title(for: UIControlState.application)
        let entry = table!.entryWithLangKey(langkey!)
        return entry
    }
    
    func reloadEntyTableWithLangKey(langkey:String){
        let entry = table?.entryWithLangKey(langkey)
        let new = SandartEntry.restoreForKey(langkey)
        entry?.Status=(new?.Status)!
    }
    
    func update(indexPath:IndexPath,withStatus status:MovieStatus){
        let cell = self.tableView(self.tableView, cellForRowAt: indexPath)
        let entry = table?.entryAtIndex(index: indexPath.row)
        entry!.Status = status
        entry!.persistForKey((entry!.LangKey))
        self.updateButton(cell:cell, withStatus: entry!.Status,indexPath: indexPath)
    }
    
    func updateButton(cell:UITableViewCell,withStatus status:MovieStatus,indexPath:IndexPath){
        let cell = cell as! LanguageTableViewCell
        let button = cell.viewWithTag(2) as! UIButton
        let langKey = button.title(for: UIControlState.application)
        let entry = table?.entryWithLangKey(langKey!)
        let progressBar = cell.viewWithTag(3) as! UIProgressView
        let priceButton = cell.viewWithTag(4) as! UIButton
        button.isHidden = false
        progressBar.isHidden = true
        priceButton.isHidden = true
        switch(status){
        case MovieStatus.NotPurchased:
            priceButton.isHidden = false
            button.isHidden = true
            priceButton.titleLabel!.text = entry!.Price
            priceButton.setTitle(entry!.Price,for:UIControlState.normal)
            priceButton.setTitle(entry!.Price,for:UIControlState.selected)
            priceButton.addTarget(self, action:#selector(SandArtViewController.purchase(_:)), for: UIControlEvents.touchUpInside)
        case MovieStatus.NotDownloaded:
            button.setImage(UIImage(named: "Download.png"), for: UIControlState.normal)
            button.imageView!.contentMode = UIViewContentMode.scaleAspectFill
            button.removeTarget(self, action: #selector(SandArtViewController.cancelDownloading(_:)), for: UIControlEvents.touchUpInside)
            button.removeTarget(self, action: #selector(SandArtViewController.play(_:)), for: UIControlEvents.touchUpInside)
            button.addTarget(self, action: #selector(SandArtViewController.download(_:)), for: UIControlEvents.touchUpInside)
        case MovieStatus.Downloading:
            progressBar.isHidden = false
            button.setImage(UIImage(named: "Stop.png"), for: UIControlState.normal)
            button.imageView?.contentMode = UIViewContentMode.scaleAspectFill
            button.removeTarget(self, action: #selector(SandArtViewController.play(_:)), for: UIControlEvents.touchUpInside)
            button.removeTarget(self, action: #selector(SandArtViewController.download(_:)), for: UIControlEvents.touchUpInside)
            button.addTarget(self, action: #selector(SandArtViewController.cancelDownloading(_:)), for: UIControlEvents.touchUpInside)
        case MovieStatus.Downloaded:
            button.setImage(UIImage(named: "Play.png"), for: UIControlState.normal)
            button.imageView?.contentMode = UIViewContentMode.scaleAspectFill
            button.removeTarget(self, action: #selector(SandArtViewController.download(_:)), for: UIControlEvents.touchUpInside)
            button.removeTarget(self, action: #selector(SandArtViewController.cancelDownloading(_:)), for: UIControlEvents.touchUpInside)
            button.addTarget(self, action: #selector(SandArtViewController.play(_:)), for: UIControlEvents.touchUpInside)
            break
        }
        
            self.tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    //MARK: - tableviewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0{
            return 1
        }
        else{
        return self.SandArtLanguages.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let Identifier = (indexPath.section == 0) ? "ImageCell" : "languageCell"
        let Rawcell = tableView.dequeueReusableCell(withIdentifier: Identifier)
         if(indexPath.section == 0)
         {
            /*let imageView = Rawcell!.viewWithTag(99) as! UIImageView
            imageView.frame = CGRect.init(x: -8, y: 0, width:self.getScreenFrameForCurrentOrientation().size.width , height: 150)
            imageView.contentMode = UIViewContentMode.scaleAspectFill*/
            Rawcell?.selectionStyle = UITableViewCellSelectionStyle.none

            return Rawcell!
         }
        else
        {
            let cell = Rawcell as! LanguageTableViewCell
            //let frame = cell.frame
            let languageLabel = cell.viewWithTag(1) as! UILabel
            let entry = table!.entryAtIndex(index: indexPath.row)
            
            
            if(entry!.Title != ""){
                languageLabel.text = entry!.Title
            }
            let actionButton = cell.contentView.viewWithTag(2) as! UIButton
            let progressBar = cell.viewWithTag(3) as! UIProgressView
            //let priceButton = cell.contentView.viewWithTag(4) as! UIButton
            
            //actionButton.frame = CGRect(x:frame.size.width-40,y:7,width:32,height:32)
            actionButton.setTitle(entry!.LangKey, for: UIControlState.application)//set product identifier for purchase
            //priceButton.frame = CGRect.init(x: frame.size.width-116, y: 7, width: 100 , height: 32)
            //progressBar.frame = CGRect(x: frame.size.width-100, y: frame.size.height/2, width: 60, height:1)
            cell.selectionStyle = UITableViewCellSelectionStyle.none
            progressBar.setProgress(downloadProgress[entry!.LangKey]!, animated: false)
            self.updateButton(cell:cell, withStatus: entry!.Status,indexPath: indexPath)
            return cell
         
        }
    }
    
    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        if(indexPath.section == 0)
        {
            return 150.0
        }
        else
        {
            return 48
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if(table==nil)
        {
            return false
        }
        if(table?.entryAtIndex(index: indexPath.row)==nil)
        {
            return false
        }
        if(indexPath.section != 0&&(table!.entryAtIndex(index: indexPath.row))!.Status == MovieStatus.Downloaded)
        {
            return true
        }
        else
        {
            return false
        }
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if(editingStyle == UITableViewCellEditingStyle.delete)
        {
            let entry = table!.entryAtIndex(index: indexPath.row)
            do{
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = documentsURL.appendingPathComponent("SandArt/" + entry!.LangKey + ".mp4")
                try FileManager.default.removeItem(at: url)
            }
            catch _{
                NSLog("file delete error :")
            }
            self.update(indexPath: indexPath, withStatus: MovieStatus.NotDownloaded)
        }
        else if (editingStyle == UITableViewCellEditingStyle.insert){
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }

    
//MARK: - In-App Purchase Handlers
    
    func validateProductIdentifiers(productIdentifiers:Array<String>)
    {
        
        SKPaymentQueue.default().add(self)
        let productRequest = SKProductsRequest.init(productIdentifiers:Set<String>(productIdentifiers))
        
        productRequest.delegate = self
        productRequest.start()
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
        self.tableView.reloadData()
    
        for identifier in response.invalidProductIdentifiers{
            NSLog("Invalid:%@",identifier)
        }
        self.displayStoreUI()
    }
    
    func productForKey(langKey:String)->SKProduct?{
       
        for p in self.products!
        {
            if(p!.productIdentifier == langKey)
            {
            return p
            }
        }
        return nil
    }
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for trans in transactions
        {
            if(trans.transactionState != SKPaymentTransactionState.purchasing)
            {
                let langKey = trans.payment.productIdentifier
                let indexPath = IndexPath.init(row: (table?.indexForLangKey(langKey))!, section: 1)
                self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.none)
            }
            switch(trans.transactionState)
            {
            case SKPaymentTransactionState.purchased:
                completeTransaction(transaction: trans)
            case SKPaymentTransactionState.failed:
                failedTransaction(transaction: trans)
            case SKPaymentTransactionState.restored:
                break//skip
            default:
                break
            }
        }
    }
    func completeTransaction(transaction:SKPaymentTransaction)
    {
        let langKey = transaction.payment.productIdentifier
        let indexPath = IndexPath.init(row: (table?.indexForLangKey(langKey))!, section: 1)
        self.update(indexPath: indexPath, withStatus: MovieStatus.NotDownloaded)
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    func failedTransaction(transaction:SKPaymentTransaction)
    {
        if (transaction.error! as! SKError).code == SKError.paymentCancelled{
            let av = UIAlertController.init(title: "Purchase Unsuccessful", message: "Your Purchase failed. Please try again", preferredStyle:.alert)
            let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil)
        
            av.addAction(cancel)
            self.present(av, animated: true, completion: nil)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
        
    }
    func displayStoreUI(){
        
        for product in self.products!{
            let langKey = product!.productIdentifier
            let entry = table!.entryWithLangKey(langKey)
            entry!.Title = product!.localizedTitle
            entry!.Price = self.formattedPrice(product: product!)
            entry!.persistForKey(langKey)
        }
        self.tableView.reloadData()
    }
    
    func formattedPrice(product:SKProduct)->String{
        let formatter = NumberFormatter.init()
        formatter.formatterBehavior = NumberFormatter.Behavior.behavior10_4
        formatter.numberStyle = NumberFormatter.Style.currency
        formatter.locale = product.priceLocale
        let formattedPrice = formatter.string(from: product.price)
        return formattedPrice!
    }
    
    func paymentRequest(product p:SKProduct?)
    {
        if(p == nil)
        {
            return;
        }
        let payment = SKMutablePayment.init(product: p!)
        SKPaymentQueue.default().add(payment)
    }
    //MARK: - Update UI
    @objc func updatePeriodically(timer:Timer){
        if self.downloadingPath.count == 0{
            timer.invalidate()
            return
        }
        else{
            self.tableView.reloadRows(at: self.downloadingPath, with: .none)
        }
    }
}