# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'Example' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Example
  pod 'QiscusCore'
  pod 'QiscusMeet', '~> 2.7'
    # 3rd party
  pod 'SDWebImage', '~> 4.4.2'
  pod 'SimpleImageViewer', :git => 'https://github.com/aFrogleap/SimpleImageViewer'
  pod 'SwiftyJSON'
  pod 'Alamofire'
  pod 'AlamofireImage'
  pod 'UICircularProgressRing', :git => 'https://github.com/luispadron/UICircularProgressRing'
end
post_install do |installer|   
      installer.pods_project.build_configurations.each do |config|
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      end
end