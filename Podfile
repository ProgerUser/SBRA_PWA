# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'SBRA PWA' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  
  # Для работы с сетью
  pod 'Alamofire', '~> 5.6'
  
  # Для работы с Keychain
  pod 'KeychainSwift', '~> 20.0'
  
  # Для работы с Excel файлами
  pod 'CoreXLSX', '~> 0.14'
  
  # Для обработки изображений
  pod 'Kingfisher', '~> 7.0'
  
  # Для пулл-ту-рефреш
  pod 'PullToRefreshKit', '~> 0.8'
  
  # Для уведомлений
  pod 'SwiftMessages', '~> 9.0'
  

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
