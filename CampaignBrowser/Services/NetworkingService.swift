import Foundation
import RxSwift
import RxCocoa


/**
 The requests which are handled by the networking service.
 */
protocol Request {

    /** The raw response type of the JSON that is returned by the server. */
    associatedtype RawResponseType

    /** The response type when the response was parsed by the application. */
    associatedtype ParsedResponseType

    /** The URL that should be requested. */
    var url: URL { get }

    /**
     A method that gets the raw response from the server and parses it to the correct type. If the parsing is not
     successful, the method should throw. The error is propagated to the consumer of the request.
     */
    func parseResponse(withData: RawResponseType) throws -> ParsedResponseType
}


/**
Responsible for handling the networking communication.
*/
class NetworkingService {

    /** The URLSession instance which is used to handle the request. */
    private let urlSession: URLSession

    /**
     Designated initializer.

     - Parameter urlSession: The URLSession instance which is used to handle the request.
     */
    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    /**
     Creates a cold observable from the given request. The observable will emit the response which was transformed via
     the `parseResponse(withData:)` method.
     */
    func createObservableResponse<T: Request>(request: T) -> Observable<T.ParsedResponseType> {
        return urlSession.rx
            .json(request: URLRequest(url: request.url))
            .catchError({ (error) -> Observable<Any> in
                let e = error as NSError
                if e.domain == NSURLErrorDomain && e.code == NSURLErrorNotConnectedToInternet {
                    throw NoInternetConnectionError()
                }
                throw ConnectionError(causedBy: error)
            })
            .map { rawData in
                guard let data = rawData as? T.RawResponseType else {
                    throw UnexpectedResponse(response: rawData)
                }
                return try request.parseResponse(withData: data)
            }
    }
}

/**
The error which is thrown when the server responded with an unexpected response.
*/
struct UnexpectedResponse: Error {

/** The server's response. */
    let response: Any
}

/**
The generic error which is thrown when connection/networking error occurs.
 */
struct ConnectionError: Error {

    /** The cause why connection error occurs. */
    let causedBy: Error
}
/**
The error which occurs when there is no internet connection.
 */
struct NoInternetConnectionError: Error {}

/**
The request which fetches the list of campaigns.
*/
class CampaignListingRequest: Request {
    typealias ResponseType = CampaignList
    typealias RawResponseType = [[String: Any]]

    /** The image service which is used to create images. */
    let imageService = ServiceLocator.instance.imageService

    var url: URL {
        // swiftlint:disable:next force_unwrapping
        return URL(string: "https://westwing-home-and-living.github.io/ios-task/campaigns.json")!
    }

    func parseResponse(withData data: [[String: Any]]) throws -> CampaignList {
        return data.flatMap { campaignData in
            guard
                let name = campaignData["name"] as? String,
                let urlKey = campaignData["url_key"] as? String,
                let description = campaignData["description"] as? String,
                let urlString = campaignData["image_url"] as? String,
                let url = URL(string: urlString)
                else {
                return nil
            }
            return Campaign(urlKey: urlKey, name: name, description: description,
                            moodImage: imageService.getImage(url: url))
        }
    }
}
