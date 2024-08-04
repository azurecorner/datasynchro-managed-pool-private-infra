using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace LinuxFunctionApp
{
    public class TimerTriggerFunction
    {
        private readonly ILogger _logger;

        public TimerTriggerFunction(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<TimerTriggerFunction>();
        }

        [Function("TimerTriggerFunction")]
        public void Run([TimerTrigger("0 */5 * * * *")] TimerInfo myTimer)
        {
            _logger.LogInformation($"C# Timer trigger function executed at: {DateTime.Now}");

            if (myTimer.ScheduleStatus is not null)
            {
                _logger.LogInformation($"Next timer schedule at: {myTimer.ScheduleStatus.Next}");
            }
        }
    }
}