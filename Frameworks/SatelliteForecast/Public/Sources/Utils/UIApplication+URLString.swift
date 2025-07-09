import UIKit

extension UIApplication {
    public static var unifiedSettingsURLString: String {
        if #available(iOS 18.3, *) {
            return UIApplication.openDefaultApplicationsSettingsURLString
        } else {
            return UIApplication.openSettingsURLString
        }
    }
}
