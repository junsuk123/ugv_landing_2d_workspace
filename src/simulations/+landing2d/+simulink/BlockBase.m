classdef (Abstract) BlockBase < matlab.System
    % BLOCKBASE  Simulink 환경 블록의 공통 포트·표본 시간 처리.
    %
    % 하위 클래스는 inputPorts/outputPorts만 정의합니다. 모든 신호는 double
    % 열벡터이고 형식은 landing2d.simulink.signalCodec이 정합니다.
    properties (Nontunable)
        SampleTime = 0.01   % 블록 표본 시간 [s]
    end

    methods (Abstract, Access = protected)
        names = inputPorts(obj)    % 입력 이름 cellstr
        ports = outputPorts(obj)   % {이름, 길이; ...}
    end

    methods
        function names = portNames(obj,direction)
            % 모델 생성기가 포트 번호를 이름으로 찾을 때 사용합니다.
            if strcmp(direction,'input')
                names = obj.inputPorts();
            else
                ports = obj.outputPorts();
                names = ports(:,1)';
            end
        end
    end

    methods (Access = protected)
        function n = getNumInputsImpl(obj)
            n = numel(obj.inputPorts());
        end
        function n = getNumOutputsImpl(obj)
            n = size(obj.outputPorts(),1);
        end
        function varargout = getInputNamesImpl(obj)
            varargout = obj.inputPorts();
        end
        function varargout = getOutputNamesImpl(obj)
            ports = obj.outputPorts();
            varargout = ports(:,1)';
        end
        function varargout = getOutputSizeImpl(obj)
            ports = obj.outputPorts();
            varargout = cellfun(@(n)[n 1],ports(:,2)','UniformOutput',false);
        end
        function varargout = getOutputDataTypeImpl(obj)
            varargout = repmat({'double'},1,size(obj.outputPorts(),1));
        end
        function varargout = isOutputComplexImpl(obj)
            varargout = repmat({false},1,size(obj.outputPorts(),1));
        end
        function varargout = isOutputFixedSizeImpl(obj)
            varargout = repmat({true},1,size(obj.outputPorts(),1));
        end
        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj,'Type','Discrete', ...
                'SampleTime',obj.SampleTime);
        end
    end

    methods (Static, Access = protected)
        function episode = currentEpisode()
            episode = landing2d.simulink.episodeServer('current');
        end
        function v = encode(kind,s)
            v = landing2d.simulink.signalCodec(kind,s);
        end
        function s = decode(kind,v)
            s = landing2d.simulink.signalCodec(kind,v);
        end
        function n = width(kind)
            n = landing2d.simulink.signalCodec('size',kind);
        end
    end
end
