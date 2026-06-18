#include <network/mco/RestRequestJob.hpp>
#include <util/JobStatus.hpp>
#include <network/mco/RestCallTagData.hpp>
#include <time.h>
#include <util/Util.hpp>
#if !defined(ANDROID) && !defined(MCPE_IOS)
#include <network/mco/CurlRestRequestJob.hpp>
#endif

std::shared_ptr<RestRequestJob> RestRequestJob::CreateJob(RestRequestType a2, std::shared_ptr<RestService> a3, Minecraft* a4) {
#if defined(ANDROID) || defined(MCPE_IOS)
	DEBUGMSG("RestRequestJob::CreateJob(stub for this platform)\n");
	// IMPORTANT: callers (Minecraft::init, LoginOption logout, PlayScreen::updateMCOStatus)
	// immediately call setBody()/setMethod()/launchRequest() on the result WITHOUT a null
	// check. Returning a null shared_ptr here means those calls dereference a null `this`,
	// which is UB. In Release the optimizer turns that into __builtin_trap (udf #0xfe ->
	// exception code 0xdefe) on the worker thread; in Debug it "happens to" survive. So we
	// must return a VALID stub object instead of null.
	std::shared_ptr<RestRequestJob> ret(new RestRequestJob());
	ret->field_8 = ret;
	ret->restService = a3;
	ret->requestType = a2;
	return ret;
#else
	std::shared_ptr<RestRequestJob> ret(new CurlRestRequestJob());
	ret->field_8 = ret; //TODO check is this actually how it is assigned
	ret->restService = a3;
	ret->requestType = a2;
	return ret;
#endif
}

RestRequestJob::RestRequestJob(){
	this->field_4 = 0;
	this->status = JS_0;
}
void RestRequestJob::launchRequest(std::shared_ptr<RestRequestJob> a1, std::shared_ptr<ThreadCollection> a2, std::function<void(int32_t, const std::string&, const RestCallTagData&, std::shared_ptr<RestRequestJob>)> a3, std::function<void(bool, bool, int32_t, const std::string&, const RestCallTagData&, std::shared_ptr<RestRequestJob>)> a4) {
	// null-tolerant: never touch a null job or enqueue against a null thread collection
	if(!a1.get() || !a2.get()) return;
	a1->field_10 = a3;
	a1->field_20 = a4;
	Job::addToThreadCollection(a1, *a2.get());
}
void RestRequestJob::setBody(const std::string& a2) {
	this->body = a2;
}

template<>
void RestRequestJob::setMethod<>(const std::string& a2) {
	std::vector<std::string> v4;
	this->field_30 = Util::simpleFormat(a2, v4);
}

template<>
void RestRequestJob::setMethod<long long,std::string,int,std::string>(const std::string& a2, long long, std::string, int, std::string);
template<>
void RestRequestJob::setMethod<long long,std::string>(const std::string& a2, long long, std::string);

void RestRequestJob::setTagData(const RestCallTagData& a2) {
	this->field_44 = a2;
}

RestRequestJob::~RestRequestJob() {
}
void RestRequestJob::stop() {
	this->status = JS_STOPPED;
}
void RestRequestJob::run() {
	// Base stub: there is no real HTTP backend on iOS/Android (no libcurl in the public SDK).
	// Just transition the job through its lifecycle so the worker/UI-thread machinery can
	// reclaim it. Do NOT touch Curl-only fields (httpStatusOrNegativeError, content, ...) -
	// they don't exist on the base class.
	this->trySetStatus(JS_STARTED);
	this->trySetStatus(JS_FINISHED);
}
void RestRequestJob::finish(){
	// Gracefully fail the online request instead of crashing. The completion callbacks
	// (field_10 / field_20) are std::function and may be empty if this job was never
	// launched, so guard before invoking. We report a network error via field_20 so the
	// MCO/Realms UI flow falls back cleanly (e.g. returns to the menu) rather than hanging.
	if(this->getStatus() == JS_STOPPED) return;
	if(this->field_20) {
		this->field_20(0, 1, -1, "", this->field_44, std::shared_ptr<RestRequestJob>(this->field_8));
	}
}
