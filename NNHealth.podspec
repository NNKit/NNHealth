#
# Be sure to run `pod lib lint NNHealth.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NNHealth'
  s.version          = '0.1.0'
  s.summary          = '获取iOS设备中健康数据'
  s.homepage         = 'https://github.com/NNKit/NNHealth'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ws00801526' => '3057600441@qq.com' }
  s.source           = { :git => 'https://github.com/NNKit/NNHealth.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'NNHealth/Classes/**/*'
  s.frameworks = 'HealthKit'
end
