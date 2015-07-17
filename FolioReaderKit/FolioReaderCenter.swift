//
//  FolioReaderCenter.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

let reuseIdentifier = "Cell"
var isScrolling = false
var scrollDirection = ScrollDirection()
var pageWidth: CGFloat!
var pageHeight: CGFloat!
var previousPageNumber: Int!
var currentPageNumber: Int!
var nextPageNumber: Int!

enum ScrollDirection: Int {
    case None
    case Right
    case Left
    case Up
    case Down
    
    init() {
        self = .None
    }
}

class FolioReaderCenter: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, FolioPageDelegate, FolioReaderContainerDelegate {
    
    var collectionView: UICollectionView!
    var pages: [String]!
    var totalPages: Int!
    var currentPage: FolioReaderPage!
    var folioReaderContainer: FolioReaderContainer!
    
    private var screenBounds: CGRect!
    private var pointNow = CGPointZero
    
    // MARK: - View life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        screenBounds = UIScreen.mainScreen().bounds
        setPageSize(UIApplication.sharedApplication().statusBarOrientation)
        
        // Layout
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsetsZero
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = UICollectionViewScrollDirection.Horizontal
        
        // CollectionView
        collectionView = UICollectionView(frame: screenBounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.pagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = UIColor.whiteColor()
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        self.view.addSubview(collectionView)
        
        // Register cell classes
        self.collectionView!.registerClass(FolioReaderPage.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Delegate container
        folioReaderContainer.delegate = self
        totalPages = book.spine.spineReferences.count
    }
    
    func reloadData() {
        totalPages = book.spine.spineReferences.count
        collectionView.reloadData()
        setCurrentPage()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        setCurrentPage()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalPages
    }
    
    private var _currentWebView:UIWebView?
    private var _currentNoteTextView:UITextView?
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! FolioReaderPage
        
        cell.webView.scrollView.delegate = self
        cell.delegate = self
        
        // Configure the cell
        let resource = book.spine.spineReferences[indexPath.row].resource
        var html: String?
        do {
            html = try String(contentsOfFile: resource.fullHref, encoding: NSUTF8StringEncoding)
        } catch _ {
            html = nil
        }
        
        // Inject CSS
        let cssFilePath = NSBundle(forClass: self.dynamicType).pathForResource("style", ofType: "css")
        let cssTag = "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssFilePath!)\">"
        
        let toInject = "\n\(cssTag) \n</head>"
        html = html?.stringByReplacingOccurrencesOfString("</head>", withString: toInject)
        
        cell.loadHTMLString(html, baseURL: NSURL(fileURLWithPath: resource.fullHref.stringByDeletingLastPathComponent))
        
        /*
        cell.webView.scrollView.alpha = 0
        cell.webView.scrollView.animateWithDuration(0.64, delay: 0, options:.CurveEaseOut, animations: {
            self.alpha = 1
            }, completion: nil)
        */
        
        /* didn't work
        // Plug tab handler
        let targetGesture = UITapGestureRecognizer(target:self, action:"handleTap")
        targetGesture.numberOfTapsRequired = 1;
        cell.webView.addGestureRecognizer(targetGesture)
        
        _currentWebView = cell.webView
        */
        
        _currentWebView = cell.webView
        
        //_currentWebView?.scrollView.touchesBegan(<#T##touches: Set<UITouch>##Set<UITouch>#>, withEvent: <#T##UIEvent?#>)
        
        let menu = UIMenuController.sharedMenuController()
        menu.menuItems = [UIMenuItem(title: "Note", action: "takeNote")]
        menu.setMenuVisible(true, animated: true)
        return cell
    }
    
    func takeNote() {
        let selectedString = _currentWebView?.stringByEvaluatingJavaScriptFromString("window.getSelection().toString()")
        print("selectedString:" + selectedString!)
        
        print("position:\(_currentWebView?.scrollView.contentOffset.x)")
        print("position:\(_currentWebView?.scrollView.contentOffset.y)")
        
        /* Fetch the current selection and its pixel location */
        let selected = _currentWebView?.stringByEvaluatingJavaScriptFromString("window.getSelection().toString();") ?? ""
        let positionString = _currentWebView?.stringByEvaluatingJavaScriptFromString("(function () {\n"
        // Fetch the selection
        + "var sel = window.getSelection();"
        + "var node = sel.anchorNode;"
        
        // Insert a dummy node that we'll use to find the selection position
        + "var range = sel.getRangeAt(0);"
        + "var dummyNode = document.createElement(\"span\");"
        + "range.insertNode(dummyNode);"
        
        // Define the functions we'll use to calculate the dummy node's position
        + "function Point(x, y) {"
        + "this.x = x;"
        + "this.y = y;"
        + "}"
        
        + "function getPoint (o) {"
        + "var oX = 0;"
        + "var oY = 0;"
        + "if (o.offsetParent) {"
        + "do {"
        + "oX += o.offsetLeft;"
        + "oY += o.offsetTop;"
        + "o=o.offsetParent;"
        + "} while (o)"
        + "} else if (o.x) {"
        + "oX += o.x;"
        + "oY += o.y;"
        + "}"
        + "return new Point(oX, oY);"
        + "}"
        
        // Get the dummy node's position and drop the node
        + "var p = getPoint(dummyNode);"
        + "dummyNode.parentNode.removeChild(dummyNode);"
        
        // Offset for the current window offset.
        + "p.x -= window.pageXOffset;"
        + "p.y -= window.pageYOffset;"
        
        // TODO - determine the text line height and offset the arrow accordingly?
        
        // Return the coordinates as a CGPointFromString() compatible {x, y} string
        + "return \"{\" + p.x + \", \" + p.y + \"}\";"
        + "})();")
        var position = CGPointFromString(positionString!)
        position = self.view.convertPoint(position, fromView: _currentWebView)
        
        /* Create our view controllers */
        /*
        WNDefinitionViewController *vc = [[[WNDefinitionViewController alloc] initWithWord: selected
        dataSource: _dataSource] autorelease];
        vc.delegate = self;
        
        UINavigationController *navVC = [[[UINavigationController alloc] initWithRootViewController: vc] autorelease];
        navVC.navigationBar.barStyle = UIBarStyleBlack;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            [self presentModalViewController: navVC animated: YES];
            
        } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController: navVC];
            popover.popoverContentSize = CGSizeMake(320, 480);
            
            [popover presentPopoverFromRect: CGRectMake(position.x, position.y, 0.0f, 0.0f)
                inView: self.view
                permittedArrowDirections: UIPopoverArrowDirectionAny
                animated: YES];
        }
        */
        print(position)
        
        // try add something
        _currentNoteTextView = UITextView(frame:  CGRect(x: position.x, y: position.y + 16, width: 240, height: 64))
        _currentNoteTextView!.text = selected + "\n"
        _currentNoteTextView!.backgroundColor = UIColor.yellowColor()
        _currentWebView?.scrollView.addSubview(_currentNoteTextView!)
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        _currentNoteTextView?.removeFromSuperview()
    }
    
    func textFieldShouldReturn(textField:UITextField) {
        print("textFieldShouldReturn:")
    }
    
    /*
    func handleTap() {
        print("contentOffset:\(_currentWebView?.scrollView.contentOffset)")
        print("selectedString:" + (_currentWebView?.selectedString)!)
    }
    */
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake(pageWidth, pageHeight)
    }
    
    // MARK: - Status Bar
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // MARK: - Device rotation
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        setPageSize(toInterfaceOrientation)
        setCurrentPage()
        
        UIView.animateWithDuration(duration, animations: { () -> Void in
            self.collectionView.contentSize = CGSizeMake(pageWidth, pageHeight * CGFloat(self.totalPages))
            self.collectionView.setContentOffset(self.frameForPage(currentPageNumber).origin, animated: false)
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    override func willAnimateRotationToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        if currentPageNumber+1 >= totalPages {
            UIView.animateWithDuration(duration, animations: { () -> Void in
                self.collectionView.setContentOffset(self.frameForPage(currentPageNumber).origin, animated: false)
            })
        }
    }
    
    // MARK: - Page
    
    func setPageSize(orientation: UIInterfaceOrientation) {
        pageWidth = orientation.isPortrait ? screenBounds.size.width : screenBounds.size.height
        pageHeight = orientation.isPortrait ? screenBounds.size.height : screenBounds.size.width
    }
    
    func setCurrentPage() {
        let currentIndexPath = getCurrentIndexPath()
        if currentIndexPath != NSIndexPath(forRow: 0, inSection: 0) {
            currentPage = collectionView.cellForItemAtIndexPath(currentIndexPath) as! FolioReaderPage
        }
        
        previousPageNumber = currentIndexPath.row == 0 ? currentIndexPath.row : currentIndexPath.row
        currentPageNumber = currentIndexPath.row+1
        nextPageNumber = currentPageNumber+1 <= totalPages ? currentPageNumber+1 : currentPageNumber
    }
    
    func getCurrentIndexPath() -> NSIndexPath {
        let indexPaths = self.collectionView.indexPathsForVisibleItems()
        var indexPath = NSIndexPath()
        
        if indexPaths.count > 1 {
            let first = indexPaths.first as NSIndexPath!
            let last = indexPaths.last as NSIndexPath!
            
            switch scrollDirection {
            case .Up:
                if first.compare(last) == NSComparisonResult.OrderedAscending {
                    indexPath = last
                } else {
                    indexPath = first
                }
            default:
                if first.compare(last) == NSComparisonResult.OrderedAscending {
                    indexPath = first
                } else {
                    indexPath = last
                }
            }
        } else {
            indexPath = indexPaths.first != nil ? indexPaths.first as NSIndexPath! : NSIndexPath(forRow: 0, inSection: 0)
        }
        
        return indexPath
    }
    
    func frameForPage(page: Int) -> CGRect {
        return CGRectMake(0, pageHeight * CGFloat(page-1), pageWidth, pageHeight)
    }
    
    // MARK: - ScrollView Delegate
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        print("scrollViewWillBeginDragging")

        isScrolling = true
        
//        if scrollView is UICollectionView {
            pointNow = scrollView.contentOffset
//        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        print("scrollViewDidScroll")
        
//        if scrollView is UICollectionView {
            scrollDirection = scrollView.contentOffset.y < pointNow.y ? .Down : .Up
//        }
    }
    
    func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        print("scrollViewWillBeginDecelerating")
//        println("decelerate")
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        print("scrollViewDidEndDecelerating")
        
        isScrolling = false
        
        if scrollView is UICollectionView {
            setCurrentPage()
            print("Page: \(currentPageNumber)")
        }
    }
    
    // MARK: - Folio Page Delegate
    
    func pageDidLoad(page: FolioReaderPage) {
//        println("Page did load")
    }
    
    // MARK: - Container delegate
    
    func container(didExpandLeftPanel sidePanel: FolioReaderSidePanel) {
        collectionView.scrollEnabled = false
        currentPage?.webView.scrollView.scrollEnabled = false
    }
    
    func container(didCollapseLeftPanel sidePanel: FolioReaderSidePanel) {
        collectionView.scrollEnabled = true
        currentPage?.webView.scrollView.scrollEnabled = true
    }
    
    func container(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference) {
        let item = findPageByResource(reference)
        let indexPath = NSIndexPath(forRow: item, inSection: 0)
        
        collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: UICollectionViewScrollPosition.Top, animated: false)
        
        let page = collectionView.cellForItemAtIndexPath(getCurrentIndexPath()) as! FolioReaderPage
        if reference.fragmentID != "" {
            page.webView.stringByEvaluatingJavaScriptFromString("window.location.hash='#\(reference.fragmentID)'")
        }
    }
    
    func findPageByResource(reference: FRTocReference) -> Int {
        var count = 0
        for item in book.spine.spineReferences {
            if item.resource.href == reference.resource.href {
                return count
            }
            count++
        }
        return count
    }
    
    func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        let page = cell as! FolioReaderPage
        page.webView.loadHTMLString("", baseURL: nil)
    }
}
