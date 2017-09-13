import UIKit
import RxSwift


/**
 The view controller responsible for listing all the campaigns. The corresponding view is the `CampaignListingView` and
 is configured in the storyboard (Main.storyboard).
 */
class CampaignListingViewController: UIViewController {

    let disposeBag = DisposeBag()

    @IBOutlet
    private(set) weak var typedView: CampaignListingView!

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(typedView != nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Load the campaign list and display it as soon as it is available.
        ServiceLocator.instance.networkingService
            .createObservableResponse(request: CampaignListingRequest())
            .observeOn(MainScheduler.instance)
            .retryWhen({ (e: Observable<Error>) -> Observable<Void> in
                return e.flatMapLatest { [weak self](error: Error) -> Observable<Void> in
                    guard let `self` = self else {
                        return Observable.empty()
                    }
                    
                    // Here we can react for different kinds of errors
                    if let _ = error as? NoInternetConnectionError {
                        let retryObserver = self.createRetryObservable()
                        return retryObserver;
                    }
                    
                    // Handle other kinds of error in case we want to retry
                    return Observable.empty()
                }
            })
            
            .subscribe(onNext: { [weak self] campaigns in
                self?.typedView.display(campaigns: campaigns)
            })
            .addDisposableTo(disposeBag)
    }
 
    private func createRetryObservable() -> Observable<Void> {
        let retryObservable = Observable<Void>.create { [weak self] observer in
            guard let `self` = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            
            let alert = UIAlertController(
                title: nil,
                message: NSLocalizedString("There was an error. Please check your internet connection and try again.", comment: "Alert Message"),
                preferredStyle: .alert)
            
            let retryAction = UIAlertAction(
                title: NSLocalizedString("retry", comment: "Alert Button"),
                style: .default) { (action) in
                    
                    observer.onNext(())
                    observer.onCompleted()
            }
            
            alert.addAction(retryAction)
            alert.preferredAction = retryAction
            
            self.present(alert, animated: true)
            
            return Disposables.create {
                alert.dismiss(animated: true, completion: nil)
            }
        }.observeOn(MainScheduler.instance)
        return retryObservable
    }
    
}
