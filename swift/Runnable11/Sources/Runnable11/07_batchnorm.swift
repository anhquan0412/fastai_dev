/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: /home/ubuntu/fastai_docs/dev_swift/07_batchnorm.ipynb/lastPathComponent

*/
        
import Path
import TensorFlow
import Python

class Reference<T> {
    var value: T
    init(_ value: T) { self.value = value }
}

public protocol LearningPhaseDependent: FALayer {
    associatedtype Input
    associatedtype Output
    
    @differentiable func forwardTraining(to input: Input) -> Output
    @differentiable func forwardInference(to input: Input) -> Output
}

public extension LearningPhaseDependent {
    @differentiable
    public func forward(_ input: Input) -> Output {
        switch Context.local.learningPhase {
        case .training: return forwardTraining(to: input)
        case .inference: return forwardInference(to: input)
        }
    }
}

public protocol Norm: Layer where Input == Tensor<Scalar>, Output == Tensor<Scalar>{
    associatedtype Scalar
    init(featureCount: Int, epsilon: Scalar)
}

public struct FABatchNorm<Scalar: TensorFlowFloatingPoint>: LearningPhaseDependent, Norm {
    // Configuration hyperparameters
    @noDerivative var momentum: Scalar
    @noDerivative var epsilon: Scalar
    // Running statistics
    @noDerivative let runningMean: Reference<Tensor<Scalar>>
    @noDerivative let runningVariance: Reference<Tensor<Scalar>>
    @noDerivative public var delegate: LayerDelegate<Output> = LayerDelegate()
    // Trainable parameters
    public var scale: Tensor<Scalar>
    public var offset: Tensor<Scalar>
    
    public init(featureCount: Int, momentum: Scalar, epsilon: Scalar = 1e-5) {
        self.momentum = momentum
        self.epsilon = epsilon
        self.scale = Tensor(ones: [featureCount])
        self.offset = Tensor(zeros: [featureCount])
        self.runningMean = Reference(Tensor(0))
        self.runningVariance = Reference(Tensor(1))
    }
    
    public init(featureCount: Int, epsilon: Scalar = 1e-5) {
        self.init(featureCount: featureCount, momentum: 0.9, epsilon: epsilon)
    }

    @differentiable
    public func forwardTraining(to input: Tensor<Scalar>) -> Tensor<Scalar> {
        let mean = input.mean(alongAxes: [0, 1, 2])
        let variance = input.variance(alongAxes: [0, 1, 2])
        runningMean.value += (mean - runningMean.value) * (1 - momentum)
        runningVariance.value += (variance - runningVariance.value) * (1 - momentum)
        let normalizer = rsqrt(variance + epsilon) * scale
        return (input - mean) * normalizer + offset
    }
    
    @differentiable
    public func forwardInference(to input: Tensor<Scalar>) -> Tensor<Scalar> {
        let mean = runningMean.value
        let variance = runningVariance.value
        let normalizer = rsqrt(variance + epsilon) * scale
        return (input - mean) * normalizer + offset
    }
}

public struct ConvBN<Scalar: TensorFlowFloatingPoint>: FALayer {
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    public var conv: FANoBiasConv2D<Scalar>
    public var norm: FABatchNorm<Scalar>
    @noDerivative public var delegate: LayerDelegate<Output> = LayerDelegate()
    
    public init(_ cIn: Int, _ cOut: Int, ks: Int = 3, stride: Int = 1){
        // TODO (when control flow AD works): use Conv2D without bias
        self.conv = FANoBiasConv2D(cIn, cOut, ks: ks, stride: stride, activation: relu)
        self.norm = FABatchNorm(featureCount: cOut, epsilon: 1e-5)
    }

    @differentiable
    public func forward(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        return norm(conv(input))
    }
}

public struct CnnModelBN: Layer {
    public var convs: [ConvBN<Float>]
    public var pool = FAGlobalAvgPool2D<Float>()
    public var linear: FADense<Float>
    
    public init(channelIn: Int, nOut: Int, filters: [Int]){
        let allFilters = [channelIn] + filters
        convs = Array(0..<filters.count).map { i in
            return ConvBN(allFilters[i], allFilters[i+1], ks: 3, stride: 2)
        }
        linear = FADense<Float>(filters.last!, nOut)
    }
    
    @differentiable
    public func call(_ input: TF) -> TF {
        return input.sequenced(through: convs, pool, linear)
    }
}
