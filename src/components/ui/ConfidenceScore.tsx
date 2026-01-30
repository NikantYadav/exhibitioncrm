interface ConfidenceScoreProps {
    confidence: number;
    label?: string;
    showPercentage?: boolean;
    size?: 'sm' | 'md' | 'lg';
}

export function ConfidenceScore({
    confidence,
    label,
    showPercentage = true,
    size = 'md'
}: ConfidenceScoreProps) {
    const percentage = Math.round(confidence * 100);

    const getColor = () => {
        if (confidence >= 0.8) return 'bg-green-500';
        if (confidence >= 0.5) return 'bg-yellow-500';
        return 'bg-red-500';
    };

    const getTextColor = () => {
        if (confidence >= 0.8) return 'text-green-700';
        if (confidence >= 0.5) return 'text-yellow-700';
        return 'text-red-700';
    };

    const getBgColor = () => {
        if (confidence >= 0.8) return 'bg-green-50';
        if (confidence >= 0.5) return 'bg-yellow-50';
        return 'bg-red-50';
    };

    const getLabel = () => {
        if (label) return label;
        if (confidence >= 0.8) return 'High';
        if (confidence >= 0.5) return 'Medium';
        return 'Low';
    };

    const sizeClasses = {
        sm: 'h-1.5',
        md: 'h-2',
        lg: 'h-3'
    };

    return (
        <div className="flex items-center gap-2">
            {/* Progress Bar */}
            <div className="flex-1 bg-gray-200 rounded-full overflow-hidden" style={{ minWidth: '60px' }}>
                <div
                    className={`${getColor()} ${sizeClasses[size]} transition-all duration-300`}
                    style={{ width: `${percentage}%` }}
                />
            </div>

            {/* Badge */}
            <span className={`px-2 py-0.5 rounded text-xs font-medium ${getTextColor()} ${getBgColor()}`}>
                {getLabel()}
                {showPercentage && ` (${percentage}%)`}
            </span>
        </div>
    );
}
