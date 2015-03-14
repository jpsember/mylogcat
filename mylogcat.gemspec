require 'rake'

Gem::Specification.new do |s|
  s.name        = 'mylogcat'
  s.version     = '0.1.0'
  s.date        = '2014-10-27'
  s.summary     = "Filter for Android logcat"
  s.authors     = ["Jeff Sember"]
  s.email       = 'jpsember@gmail.com'
  s.files = FileList['lib/**/*.rb',
                      'bin/*',
                      '[A-Z]*',
                      'test/**/*',
                      ]
  s.executables << s.name
  s.add_runtime_dependency 'js_base'
  s.homepage = 'http://www.cs.ubc.ca/~jpsember'
  s.test_files  = Dir.glob('test/*.rb')
  s.license     = 'MIT'
end

