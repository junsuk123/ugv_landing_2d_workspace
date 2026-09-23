function test_config_validation()
% TEST_CONFIG_VALIDATION  잘못된 옵션/투명도/색상 입력 거부.
c = landing2d.config.defaultConfig();
landing2d.config.validateConfig(c);
rejected = false;
try
    landing2d.config.applyOptions(c,struct('typoSpeed',3));
catch err
    rejected = strcmp(err.identifier,'landing2d:UnknownOption');
end
assert(rejected);
c.segmentAlpha = 1.2;
rejected = false;
try
    landing2d.config.validateConfig(c);
catch
    rejected = true;
end
assert(rejected);
end
